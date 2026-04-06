from __future__ import annotations

import json
import time
from typing import Any

from fastapi import FastAPI, WebSocket
from pydantic import ValidationError
from starlette.websockets import WebSocketDisconnect

from inference import get_inference_engine
from protocol import ErrorResponse, GenerateRequest, ResultResponse

app = FastAPI(title="Piano Dialogue Server", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.websocket("/ws")
async def ws_endpoint(websocket: WebSocket) -> None:
    await websocket.accept()
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                payload: Any = json.loads(raw)
            except Exception:
                await websocket.send_json(ErrorResponse(message="invalid json").model_dump())
                continue

            if not isinstance(payload, dict):
                await websocket.send_json(ErrorResponse(message="invalid payload").model_dump())
                continue

            message_type = payload.get("type")
            if message_type != "generate":
                await websocket.send_json(
                    ErrorResponse(message=f"unsupported type: {message_type!r}").model_dump()
                )
                continue

            try:
                request = GenerateRequest.model_validate(payload)
            except ValidationError as error:
                await websocket.send_json(ErrorResponse(message=str(error)).model_dump())
                continue

            try:
                engine = get_inference_engine()
                t0 = time.perf_counter()
                reply_notes = engine.generate_response(request.notes, request.params, request.session_id)
                latency_ms = int((time.perf_counter() - t0) * 1000)
                response = ResultResponse(notes=reply_notes, latency_ms=latency_ms)
                await websocket.send_json(response.model_dump())
            except Exception as error:  # noqa: BLE001
                await websocket.send_json(ErrorResponse(message=str(error)).model_dump())
    except WebSocketDisconnect:
        return
