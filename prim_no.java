import java.util.Scanner;
class prim_no {
    public static void main (String [] args) {
        Scanner s = new Scanner(System.in);
        System.out.println("enter");
        int a = s.nextInt();
        for (int i = 2; i<a;i++){
            cal(i);
        }
    }
    static void cal(int a) {
        boolean v = true;
            for(int i = 2; i<a; i++) {
                if (a%i == 0) {
                    v = false;
                }
            }
            if ( v == true) {
                System.out.print(" " + a + " ");
            }
    }
}