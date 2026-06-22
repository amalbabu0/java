require("dotenv").config({ quiet: true });

const crypto = require("crypto");
const fs = require("fs");
const http = require("http");
const path = require("path");
const Razorpay = require("razorpay");

const PORT = Number(process.env.PORT || 3000);
const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || "";
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || "";
const CURRENCY = "INR";
const MIN_AMOUNT_PAISE = 100;
const orderStore = new Map();

const razorpay = RAZORPAY_KEY_ID && RAZORPAY_KEY_SECRET
  ? new Razorpay({
      key_id: RAZORPAY_KEY_ID,
      key_secret: RAZORPAY_KEY_SECRET
    })
  : null;

const products = [
  {
    id: "pulse-headphones",
    name: "Pulse Wireless Headphones",
    description: "Noise-softening over-ear audio with 40 hours of battery.",
    pricePaise: 100,
    badge: "Audio",
    image: "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=900&q=80",
    alt: "Black wireless headphones on a bright background"
  },
  {
    id: "loop-smartwatch",
    name: "Loop Smart Watch",
    description: "Lightweight fitness tracking with calls, steps and sleep insights.",
    pricePaise: 200,
    badge: "Wearable",
    image: "https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=900&q=80",
    alt: "Smart watch with a clean strap on a tabletop"
  },
  {
    id: "city-backpack",
    name: "City Day Backpack",
    description: "Water-resistant daily bag with a padded laptop section.",
    pricePaise: 100,
    badge: "Travel",
    image: "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=900&q=80",
    alt: "Brown backpack photographed in natural light"
  },
  {
    id: "nova-sneakers",
    name: "Nova Run Sneakers",
    description: "Cushioned everyday sneakers with breathable knit support.",
    pricePaise: 200,
    badge: "Footwear",
    image: "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=900&q=80",
    alt: "Red running shoes floating above a red surface"
  }
];

const contentTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml"
};

function sendJson(response, statusCode, data) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store"
  });
  response.end(JSON.stringify(data));
}

function readJson(request) {
  return new Promise((resolve, reject) => {
    let body = "";

    request.on("data", (chunk) => {
      body += chunk;
      if (body.length > 1_000_000) {
        const error = new Error("Request body is too large.");
        error.statusCode = 413;
        reject(error);
        request.destroy();
      }
    });

    request.on("end", () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (error) {
        const parseError = new Error("Invalid JSON request body.");
        parseError.statusCode = 400;
        reject(parseError);
      }
    });

    request.on("error", reject);
  });
}

function getProduct(productId) {
  return products.find((product) => product.id === productId);
}

function ensureRazorpayKeys() {
  if (!razorpay) {
    const error = new Error("Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET before starting the server.");
    error.statusCode = 503;
    throw error;
  }
}

function toRazorpayError(error) {
  const statusCode = Number(error.statusCode || error.status || 500);
  const mappedError = new Error(
    error.error && error.error.description
      ? error.error.description
      : error.description || error.message || "Razorpay API request failed."
  );

  mappedError.statusCode = statusCode === 401 ? 401 : 500;
  return mappedError;
}

function parseAmount(value) {
  const amount = Number(value);
  return Number.isInteger(amount) ? amount : 0;
}

function createReceipt(productId) {
  const safeId = String(productId || "order").replace(/[^a-z0-9_-]/gi, "").slice(0, 12);
  return `rcpt_${safeId}_${Date.now()}`.slice(0, 40);
}

function resolveOrderRequest(body) {
  const product = body.productId ? getProduct(body.productId) : null;

  if (body.productId && !product) {
    const error = new Error("Invalid product selected.");
    error.statusCode = 400;
    throw error;
  }

  const amount = product ? product.pricePaise : parseAmount(body.amount);
  if (amount < MIN_AMOUNT_PAISE) {
    const error = new Error("Amount must be at least 100 paise.");
    error.statusCode = 400;
    throw error;
  }

  const currency = String(body.currency || CURRENCY).toUpperCase();
  if (!/^[A-Z]{3}$/.test(currency)) {
    const error = new Error("Currency must be a 3-letter code.");
    error.statusCode = 400;
    throw error;
  }

  const receipt = String(body.receipt || createReceipt(product && product.id)).slice(0, 40);

  return {
    product,
    amount,
    currency,
    receipt
  };
}

async function createOrder(request, response) {
  ensureRazorpayKeys();

  const body = await readJson(request);
  const orderRequest = resolveOrderRequest(body);

  try {
    const order = await razorpay.orders.create({
      amount: orderRequest.amount,
      currency: orderRequest.currency,
      receipt: orderRequest.receipt,
      notes: orderRequest.product
        ? {
            product_id: orderRequest.product.id,
            product_name: orderRequest.product.name
          }
        : {}
    });

    orderStore.set(order.id, {
      id: order.id,
      amount: order.amount,
      currency: order.currency,
      receipt: order.receipt,
      productId: orderRequest.product && orderRequest.product.id,
      productName: orderRequest.product && orderRequest.product.name,
      createdAt: Date.now()
    });

    sendJson(response, 200, {
      order_id: order.id,
      amount: order.amount,
      currency: order.currency
    });
  } catch (error) {
    throw toRazorpayError(error);
  }
}

function verifySignature(orderId, paymentIdValue, signature) {
  const expectedSignature = crypto
    .createHmac("sha256", RAZORPAY_KEY_SECRET)
    .update(`${orderId}|${paymentIdValue}`)
    .digest("hex");

  const expectedBuffer = Buffer.from(expectedSignature, "hex");
  const actualBuffer = Buffer.from(signature, "hex");

  return (
    expectedBuffer.length === actualBuffer.length &&
    crypto.timingSafeEqual(expectedBuffer, actualBuffer)
  );
}

function getVerifiedOrder(orderId) {
  const order = orderStore.get(orderId);
  if (!order) {
    const error = new Error("Order not found on server. Create a fresh order and try again.");
    error.statusCode = 400;
    throw error;
  }

  return order;
}

function markOrderPaid(order, paymentIdValue) {
  const orderNumber = `ORD-${Date.now().toString().slice(-8)}`;

  orderStore.set(order.id, {
    ...order,
    status: "paid",
    paymentId: paymentIdValue,
    orderNumber,
    paidAt: Date.now()
  });

  return {
    status: "placed",
    orderNumber,
    productId: order.productId || null,
    productName: order.productName || "Selected product",
    paymentId: paymentIdValue
  };
}

async function verifyPayment(request, response) {
  ensureRazorpayKeys();

  const body = await readJson(request);
  const orderId = String(body.razorpay_order_id || "");
  const paymentIdValue = String(body.razorpay_payment_id || "");
  const signature = String(body.razorpay_signature || "");

  if (!orderId || !paymentIdValue || !signature) {
    sendJson(response, 400, { message: "Missing payment verification fields." });
    return;
  }

  const order = getVerifiedOrder(orderId);

  if (!verifySignature(order.id, paymentIdValue, signature)) {
    sendJson(response, 400, { message: "Payment signature verification failed." });
    return;
  }

  sendJson(response, 200, markOrderPaid(order, paymentIdValue));
}

function serveStatic(request, response, pathname) {
  if (pathname !== "/" && pathname !== "/index.html") {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Not found");
    return;
  }

  const filePath = path.resolve(__dirname, "index.html");

  fs.readFile(filePath, (error, content) => {
    if (error) {
      response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      response.end("Not found");
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    response.writeHead(200, {
      "Content-Type": contentTypes[ext] || "application/octet-stream",
      "Cache-Control": "no-store"
    });
    response.end(content);
  });
}

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, `http://${request.headers.host}`);

  try {
    if (request.method === "GET" && url.pathname === "/api/config") {
      sendJson(response, 200, {
        keyConfigured: Boolean(RAZORPAY_KEY_ID && RAZORPAY_KEY_SECRET),
        keyId: RAZORPAY_KEY_ID,
        currency: CURRENCY
      });
      return;
    }

    if (request.method === "GET" && url.pathname === "/api/products") {
      sendJson(response, 200, { products });
      return;
    }

    if (request.method === "POST" && url.pathname === "/api/create-order") {
      await createOrder(request, response);
      return;
    }

    if (request.method === "POST" && url.pathname === "/api/verify-payment") {
      await verifyPayment(request, response);
      return;
    }

    if (request.method === "GET") {
      serveStatic(request, response, url.pathname);
      return;
    }

    sendJson(response, 405, { message: "Method not allowed." });
  } catch (error) {
    sendJson(response, error.statusCode || 500, {
      message: error.message || "Server error."
    });
  }
});

server.listen(PORT, () => {
  console.log(`SwiftCart running at http://localhost:${PORT}`);
});
