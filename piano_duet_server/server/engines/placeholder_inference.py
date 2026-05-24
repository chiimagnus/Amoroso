from __future__ import annotations

import random
from dataclasses import dataclass
from typing import Protocol

from ..api.protocol import DialogueNote, GenerateParams


class InferenceEngineProtocol(Protocol):
    def generate_response(
        self,
        notes: list[DialogueNote],
        params: GenerateParams,
        session_id: str | None,
    ) -> list[DialogueNote]: ...


def _clamp_int(value: int, lower: int, upper: int) -> int:
    return max(lower, min(upper, value))


def _clamp_float(value: float, lower: float, upper: float) -> float:
    return max(lower, min(upper, value))


def _legalize_notes(notes: list[DialogueNote]) -> list[DialogueNote]:
    legalized: list[DialogueNote] = []
    for note in notes:
        legalized.append(
            DialogueNote(
                note=_clamp_int(int(note.note), 0, 127),
                velocity=_clamp_int(int(note.velocity), 0, 127),
                time=_clamp_float(float(note.time), 0.0, 1_000_000.0),
                duration=_clamp_float(float(note.duration), 0.01, 1_000_000.0),
            )
        )
    legalized.sort(key=lambda item: (item.time, item.note))
    return legalized


@dataclass(frozen=True)
class PlaceholderInferenceEngine:
    def generate_response(
        self,
        notes: list[DialogueNote],
        params: GenerateParams,
        session_id: str | None,
    ) -> list[DialogueNote]:
        # A simple, deterministic-ish arpeggio based on the last heard note.
        last_note = 60
        last_velocity = 90
        if notes:
            tail = max(notes, key=lambda item: (item.time + item.duration, item.time))
            last_note = int(tail.note)
            last_velocity = int(tail.velocity)

        rng = random.Random(params.seed if params.seed is not None else 0)
        pattern = [0, 4, 7, 12, 7, 4]
        base = _clamp_int(last_note, 36, 84)
        velocity = _clamp_int(max(40, min(110, last_velocity)), 0, 127)

        reply: list[DialogueNote] = []
        step = 0.18
        dur = 0.16
        for i in range(len(pattern)):
            pitch = base + pattern[i] + rng.choice([0, 0, 0, 12])
            reply.append(
                DialogueNote(
                    note=_clamp_int(pitch, 0, 127),
                    velocity=velocity,
                    time=float(i) * step,
                    duration=dur,
                )
            )

        return _legalize_notes(reply)


_ENGINE: InferenceEngineProtocol | None = None


def get_inference_engine() -> InferenceEngineProtocol:
    global _ENGINE  # noqa: PLW0603
    if _ENGINE is None:
        _ENGINE = PlaceholderInferenceEngine()
    return _ENGINE
