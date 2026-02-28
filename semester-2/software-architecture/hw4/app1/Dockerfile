FROM python:3.9-slim
RUN pip install "fastapi[standard]" kafka-python
COPY ./app.py /home/app/
CMD ["fastapi", "run", "/home/app/app.py", "--port", "8000"]
