import java.util.Scanner;
class strong {
    public static void main (String [] args) {
        Scanner s = new Scanner(System.in);
        System.out.println("enter");
        int a = s.nextInt();
        int b = a;
        if (digs(a) == b){
            System.out.print(digs(a) + "=" + b);
            System.out.println("yes");
        } else {
            System.out.println("no");
        }
    }
    static int digs(int a) {
        int rev = 0;
        while(a != 0) {
            int n = a%10;
            rev = rev + fact(n);
            a=a/10;
        }
        return rev;
    }
    static int fact(int n) {
        if (n == 0) {
            return 1;
        } else {
            return n * fact(n-1);  // Fixed here
        }
    }
}