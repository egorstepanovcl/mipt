import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;

public class Task2 {
    public static void main(String[] args) {
        String fileName = "output.txt";

        try (FileWriter fileWriter = new FileWriter(fileName);
             BufferedWriter bufferedWriter = new BufferedWriter(fileWriter)) {

            for (int i = 1; i <= 10; i++) {
                bufferedWriter.write("Запись " + i);
                bufferedWriter.newLine(); // Переход на новую строку
            }

            bufferedWriter.write("Файл успешно записан");
            bufferedWriter.newLine();

            System.out.println("Данные успешно записаны в файл " + fileName);

        } catch (IOException e) {
            System.out.println("Ошибка при записи в файл: " + e.getMessage());
        }
    }
}

