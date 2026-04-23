import java.util.Scanner;
class amstrong {
    public static void main (String[] args) {
        Scanner s = new Scanner(System.in);
        System.out.println("enter");
        int a = s.nextInt();
        int b =a;
        int d = 0;
        while (a != 0) {
            int c = a%10;
            d = d + (c*c*c);
            a = a/10;
        }
        System.out.println(b);
        System.out.println(d);
        if (b == d) {
            System.out.println("yes");
        } else {
           System.out.println("no"); 
        }
    }
}