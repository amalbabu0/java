import java.util.Scanner;
class perfect {
    public static void main(String[] args) {
        Scanner s = new Scanner(System.in);
        int a = s.nextInt();
        int b = a;
        if (div(a) == b) {
            System.out.println("yes");
        } else {
            System.out.println("no");
        }
    }
    static int div(int a) {
        int d = 1;
        int i = 2;
        while (i != a) {
            if(a%i==0){
                d = d + i;
            }
            i++;
        }
        return d;
    }
}