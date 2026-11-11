from datetime import datetime, timedelta

import FinanceDataReader as fdr
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def read_home():
    return {"hello": "world"}


@app.get("/samsung")
def read_samsung(days: int = 30):
    """삼성전자(005930) 최근 주가 데이터를 JSON으로 반환"""
    start = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
    df = fdr.DataReader("005930", start)

    df = df.reset_index()
    df["Date"] = df["Date"].dt.strftime("%Y-%m-%d")

    return {
        "code": "005930",
        "name": "삼성전자",
        "data": df.to_dict(orient="records"),
    }
