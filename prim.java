import java.util.Scanner;
class prim {
    static void cal(int a) {
        boolean v = true;
        if (a <=1 ) {
            System.out.println("no");
        } else {
            for(int i = 2; i<a; i++) {
                if (a%i==0) {
                    v = false;
                    break;
                }
            }
            if (v == true) {
                System.out.println("yes");
            } else {
                System.out.println("no");
            }
        }
    }
    public static void main(String[] args) {
        Scanner s = new Scanner(System.in);
        System.out.println("enter");
        int a = s.nextInt();
        cal(a);
    }
}