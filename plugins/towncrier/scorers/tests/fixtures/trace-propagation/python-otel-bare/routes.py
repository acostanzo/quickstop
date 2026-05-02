from .main import app


@app.get("/items")
def get_items():
    return {"items": []}


@app.post("/items")
def post_items():
    return {}
