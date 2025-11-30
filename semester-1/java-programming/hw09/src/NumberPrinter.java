public class NumberPrinter implements Runnable {
    private final int start;
    private final int end;
    private final String threadName;

    public NumberPrinter(int start, int end, String threadName) {
        this.start = start;
        this.end = end;
        this.threadName = threadName;
    }

    @Override
    public void run() {
        for (int i = start; i <= end; i++) {
            System.out.println(threadName + ": " + i);

            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                System.out.println(threadName + " был прерван");
                Thread.currentThread().interrupt();
                return;
            }
        }

        System.out.println(threadName + " завершил работу");
    }
}

