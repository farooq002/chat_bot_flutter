✅ Do This Step-by-Step
1. Create a virtual environment (only once)
From your backend folder:
python3 -m venv venv

2. Activate the virtual environment
source venv/bin/activate


After activation, your terminal will show:
(venv) noorali@Mac backend %


pip install git+https://github.com/openai/whisper.git

run
uvicorn main:app --reload --host 0.0.0.0 --port 8000
uvicorn main:app --reload