from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field, field_validator, EmailStr
from typing import List
from datetime import datetime, date
import json
import re
from pathlib import Path
from uuid import uuid4

app = FastAPI(title="Сервис обращений абонентов")

STORAGE_DIR = Path("appeals")
STORAGE_DIR.mkdir(exist_ok=True)


class AppealRequest(BaseModel):
    
    lastname: str = Field(..., description="Фамилия с заглавной буквы (только кирилица)")
    firstname: str = Field(..., description="Имя с заглавной буквы (только кирилица)")
    birth_date: date = Field(..., description="Дата рождения")
    phone: str = Field(..., description="Номер телефона")
    email: EmailStr = Field(..., description="Электронная почта")
    issues: List[str] = Field(..., min_length=1, description="Список причин обращения")
    issue_datetime: datetime = Field(..., description="Дата и время обнаружения проблемы")
    
    @field_validator('lastname', 'firstname')
    @classmethod
    def validate_cyrillic_capitalized(cls, v: str, info) -> str:
        if not v:
            raise ValueError(f'{info.field_name} не может быть пустым')
        
        if not re.match(r'^[А-ЯЁ][а-яё]+$', v):
            raise ValueError(
                f'{info.field_name} должно начинаться с заглавной буквы '
                'и содержать только кирилицу'
            )
        
        return v
    
    @field_validator('phone')
    @classmethod
    def validate_phone(cls, v: str) -> str:
        cleaned = re.sub(r'[^\d+]', '', v)
        
        if not re.match(r'^(\+7|8)\d{10}$', cleaned):
            raise ValueError(
                'Номер телефона должен быть в формате +79991234567 или 89991234567'
            )
        
        return cleaned
    
    @field_validator('issues')
    @classmethod
    def validate_issues(cls, v: List[str]) -> List[str]:
        allowed_issues = {
            'нет доступа к сети',
            'не работает телефон',
            'не приходят письма'
        }
        
        for issue in v:
            if issue not in allowed_issues:
                raise ValueError(
                    f'Недопустимая причина обращения: "{issue}". '
                    f'Доступные варианты: {", ".join(allowed_issues)}'
                )
        
        return list(dict.fromkeys(v))
    
    @field_validator('issue_datetime')
    @classmethod
    def validate_issue_datetime(cls, v: datetime) -> datetime:
        if v > datetime.now():
            raise ValueError('Дата обнаружения проблемы не может быть в будущем')
        
        return v
    
    @field_validator('birth_date')
    @classmethod
    def validate_birth_date(cls, v: date) -> date:
        if v >= date.today():
            raise ValueError('Дата рождения должна быть в прошлом')
        
        age = (date.today() - v).days // 365
        if age < 0 or age > 150:
            raise ValueError('Некорректная дата рождения')
        
        return v


class AppealResponse(BaseModel):
    appeal_id: str
    message: str
    saved_data: dict


@app.post("/appeals/", response_model=AppealResponse, status_code=201)
async def create_appeal(appeal: AppealRequest):
    try:
        appeal_id = str(uuid4())
        
        appeal_data = appeal.model_dump(mode='json')
        appeal_data['appeal_id'] = appeal_id
        appeal_data['created_at'] = datetime.now().isoformat()
        
        file_path = STORAGE_DIR / f"appeal_{appeal_id}.json"
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(appeal_data, f, ensure_ascii=False, indent=2)
        
        return AppealResponse(
            appeal_id=appeal_id,
            message="Обращение успешно сохранено",
            saved_data=appeal_data
        )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка сохранения: {str(e)}")


@app.get("/appeals/{appeal_id}")
async def get_appeal(appeal_id: str):
    file_path = STORAGE_DIR / f"appeal_{appeal_id}.json"
    
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Обращение не найдено")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

