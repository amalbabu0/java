import java.util.Scanner;
class fibbonacii {
    public static void main(String[] args) {
        Scanner s = new Scanner(System.in);
        System.out.println("enetr");
        int n = s.nextInt();
        int f1 = 0;
        int f2 = 1;
        if (n>1) {
            System.out.println(f1);
            System.out.println(f2);
        } else {
            System.out.println("no");
        }
        for (int i=0; i<n; i++) {
            int f3 = f1+f2;
            f1 = f2;
            f2 = f3;
            System.out.println(f2);
        }
    }
}

