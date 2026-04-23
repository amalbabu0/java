class count {
    public static void main (String[] args) {
        int a = -124;
        int b;
        int c = 0;
        do {
            b = a / 10;
            c++;
        } while (b != 0);
        System.out.println(c);
    }
}