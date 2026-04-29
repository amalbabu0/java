import java.util.Scanner;
class linear_search {
    public static void main (String[] args) {
        Scanner s = new Scanner(System.in);
        int a[] = {1,3,6,3,6,3,6,88,9};
        System.out.println("enter");
        int n = s.nextInt();
        for(int i = 0; i<a.length - 1; i++) {
            if (a[i] == n) {
                System.out.println("found at " + i);
            }
        }
    }
}