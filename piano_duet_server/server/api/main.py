from __future__ import annotations

import time
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .protocol import GenerateRequest, ResultResponse


@asynccontextmanager
async def _lifespan(_: FastAPI):
    yield


app = FastAPI(title="Piano Duet Server", version="0.1.0", lifespan=_lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/generate")
async def generate(request: GenerateRequest) -> ResultResponse:
    from ..engines.placeholder_inference import get_inference_engine

    t0 = time.perf_counter()
    engine = get_inference_engine()
    reply_notes = engine.generate_response(request.notes, request.params, request.session_id)
    latency_ms = int((time.perf_counter() - t0) * 1000)
    return ResultResponse(notes=reply_notes, latency_ms=latency_ms)
