import java.util.Scanner;
class palindrome {
    public static void main (String[] args) {
        Scanner s = new Scanner(System.in) ;
        System.out.println("enter");
        int a = s.nextInt();
        int rev = 0;
        int b = a;
        try {
            while (b != 0 ) {
                int n = b%10;
                rev = rev * 10 + n;
                b = b/10;
            }
            System.out.println(rev);
            System.out.println(a);
            System.out.println(b);
            if (a == rev ) {
                System.out.println("yes");
            } else {
                System.out.println("no");
            }
        } catch (Exception ex) {
            System.out.println("error");
        }
    }
}