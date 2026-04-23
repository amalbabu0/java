class sum_digits {
    static int rev (int a) {
        if (a == 0) {
            return 1;
        } else {
            return a = a + rev(a-1);
        }
    }
    public static void main (String [] args) {
        int a = 4;
        System.out.println(rev(a)-1);
    }
}