import java.util.Scanner;
class max_min {
    public static void main(String[] args) {
        Scanner s = new Scanner(System.in);
        System.out.println("enter limit");
        int n = s.nextInt();
        int a[] = new int[n];
        System.out.println("enter " + n + "values");
        for(int i=0; i<n; i++) {
            a[i] = s.nextInt();
        }
        int min = a[0];
        int max = a[0];
        for(int i=0; i<n; i++) {
            if (a[i]<min){
                min = a[i];
            } else if (a[i] > max) {
                max = a[i];
            }
        }
        System.out.println("min" +min);
        System.out.println("max" +max);
    }
}