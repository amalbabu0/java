import java.util.Scanner;
class factoraial {
    static int fact(int a) {
        if(a==0) {
            return 1;
        } else {
            return a= a * fact(a-1);
        }
    }
    public static void main(String[] args) {
        Scanner s = new Scanner(System.in);
        System.out.println("enter the no");
        int a = s.nextInt();
        System.out.println(fact(a));
    }
}