public class Main {
    public static void main(String[] args) {
        NumberPrinter printer1 = new NumberPrinter(1, 10, "Поток 1");
        NumberPrinter printer2 = new NumberPrinter(11, 20, "Поток 2");

        Thread thread1 = new Thread(printer1);
        Thread thread2 = new Thread(printer2);

        System.out.println("Запуск потоков...");
        thread1.start();
        thread2.start();

        try {
            thread1.join();
            thread2.join();
        } catch (InterruptedException e) {
            System.out.println("Главный поток был прерван");
            Thread.currentThread().interrupt();
        }

        System.out.println("Все потоки завершили работу");
    }
}

