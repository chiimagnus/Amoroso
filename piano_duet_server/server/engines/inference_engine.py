from __future__ import annotations

import os

from .inference_engine_protocol import InferenceEngineProtocol


_ENGINE: InferenceEngineProtocol | None = None


def get_inference_engine() -> InferenceEngineProtocol:
    global _ENGINE  # noqa: PLW0603
    if _ENGINE is not None:
        return _ENGINE

    engine_name = os.environ.get("DUET_ENGINE", "auto").strip().lower()
    if engine_name in ("placeholder", "stub"):
        from .placeholder_inference import PlaceholderInferenceEngine

        _ENGINE = PlaceholderInferenceEngine()
        return _ENGINE

    if engine_name in ("auto", "magenta"):
        try:
            from .magenta_performance_rnn import MagentaPerformanceRNNEngine

            _ENGINE = MagentaPerformanceRNNEngine()
            return _ENGINE
        except Exception as error:  # noqa: BLE001
            # Best-effort: keep the server usable even if Magenta isn't installed.
            print(f"[DuetEngine] magenta unavailable, fallback placeholder: {type(error).__name__}: {error!r}")
            from .placeholder_inference import PlaceholderInferenceEngine

            _ENGINE = PlaceholderInferenceEngine()
            return _ENGINE

    print(f"[DuetEngine] unknown DUET_ENGINE={engine_name!r}, fallback placeholder")
    from .placeholder_inference import PlaceholderInferenceEngine

    _ENGINE = PlaceholderInferenceEngine()
    return _ENGINE
