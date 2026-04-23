class reverse {
    public static void main (String [] args) {
        int a = 1234;
        int rev = 0; 
        while (a != 0){
            int n = a%10;
            rev = rev * 10 + n;
            a = a/10;
        }
        System.out.println(rev);
    }
}