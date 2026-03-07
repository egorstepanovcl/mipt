.PHONY: install test clean

VENV        = venv
PYTHON      = $(VENV)/bin/python3
ACTIVATE    = . $(VENV)/bin/activate

install:
	python3 -m venv $(VENV)
	$(ACTIVATE) && pip install --upgrade pip && pip install -r requirements.txt

test:
	$(ACTIVATE) && $(PYTHON) -m pytest test_booking_service_Stepanov_Egor_Viktorovich.py -v

clean:
	rm -rf $(VENV) .pytest_cache __pycache__

