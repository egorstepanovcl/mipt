import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.SocketChannel;

public class NioClient {
    private static final String SERVER_HOST = "localhost";
    private static final int SERVER_PORT = 5050;

    public static void main(String[] args) {
        try {
            connectToServer();
        } catch (IOException e) {
            System.err.println("Ошибка клиента: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private static void connectToServer() throws IOException {
        SocketChannel socketChannel = SocketChannel.open();

        try {
            socketChannel.connect(new InetSocketAddress(SERVER_HOST, SERVER_PORT));
            System.out.println("Подключено к серверу " + SERVER_HOST + ":" + SERVER_PORT);

            ByteBuffer buffer = ByteBuffer.allocate(256);
            int bytesRead = socketChannel.read(buffer);

            if (bytesRead > 0) {
                buffer.flip();
                byte[] data = new byte[buffer.remaining()];
                buffer.get(data);
                String message = new String(data);

                System.out.println("Получено от сервера: " + message);
            }

        } catch (IOException e) {
            System.err.println("Ошибка подключения к серверу: " + e.getMessage());
            throw e;
        } finally {
            try {
                socketChannel.close();
                System.out.println("Соединение закрыто");
            } catch (IOException e) {
                System.err.println("Ошибка при закрытии соединения: " + e.getMessage());
            }
        }
    }
}

