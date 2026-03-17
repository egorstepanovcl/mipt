.PHONY: install run clean

VENV        = venv
PYTHON      = $(VENV)/bin/python3
ACTIVATE    = . $(VENV)/bin/activate

install:
	python3 -m venv $(VENV)
	$(ACTIVATE) && pip install --upgrade pip

run:
	$(ACTIVATE) && $(PYTHON) HW4_Stepanov_Egor_Viktorovich.py

clean:
	rm -rf $(VENV) __pycache__
