import java.util.Scanner;
class hcf {
    public static void main (String[] args){
        Scanner s = new Scanner(System.in);
        System.out.println("enter");
        int a = s.nextInt();
        int b = s.nextInt();
        while ( b != 0) {
            int hcf = a%b;
            a = b;
            b = hcf;
        }
        System.out.println(a);
    }
}