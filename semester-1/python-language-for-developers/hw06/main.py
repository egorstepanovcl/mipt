from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import operator
import re
import uvicorn

app = FastAPI()


class ExprPart(BaseModel):
    a: float
    op: str
    b: float


class Expression(BaseModel):
    expression: str


current_expression = ""

ops = {
    '+': operator.add,
    '-': operator.sub,
    '*': operator.mul,
    '/': operator.truediv,
}


@app.post("/calc/simple")
def simple_calc(expr: ExprPart):
    if expr.op not in ops:
        raise HTTPException(status_code=400, detail="Unsupported operation")
    if expr.op == '/' and expr.b == 0:
        raise HTTPException(status_code=400, detail="Division by zero")
    result = ops[expr.op](expr.a, expr.b)
    return {"result": result}


@app.post("/calc/expression")
def set_expression(expr: Expression):
    global current_expression
    if not re.fullmatch(r"[0-9+\-*/().\s]+", expr.expression):
        raise HTTPException(status_code=400, detail="Invalid characters in expression")
    current_expression = expr.expression
    return {"expression": current_expression}


@app.get("/calc/expression")
def get_expression():
    return {"expression": current_expression}


@app.get("/calc/evaluate")
def evaluate_expression():
    global current_expression
    try:
        result = eval(current_expression, {"__builtins__": None}, {})
    except ZeroDivisionError:
        raise HTTPException(status_code=400, detail="Division by zero")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid expression")
    return {"result": result}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
