from __future__ import annotations

from ..api.protocol import DialogueNote


def _resolve_music_pb2():  # type: ignore[no-untyped-def]
    try:
        from note_seq.protobuf import music_pb2  # type: ignore[import-not-found]

        return music_pb2
    except Exception:
        from magenta.protobuf import music_pb2  # type: ignore[import-not-found]

        return music_pb2


def dialogue_notes_to_note_sequence(
    notes: list[DialogueNote],
    qpm: float = 120.0,
):
    music_pb2 = _resolve_music_pb2()

    sequence = music_pb2.NoteSequence()
    if qpm > 0:
        sequence.tempos.add(qpm=float(qpm))

    max_end = 0.0
    for note in notes:
        start_time = float(note.time)
        end_time = start_time + float(note.duration)
        max_end = max(max_end, end_time)
        sequence.notes.add(
            pitch=int(note.note),
            velocity=int(note.velocity),
            start_time=start_time,
            end_time=end_time,
        )

    sequence.total_time = max_end
    return sequence


def note_sequence_to_dialogue_notes(
    sequence,
    *,
    start_at_sec: float,
) -> list[DialogueNote]:
    reply: list[DialogueNote] = []
    for note in getattr(sequence, "notes", []):
        if float(note.start_time) < start_at_sec:
            continue

        start_time = float(note.start_time) - start_at_sec
        duration = max(0.01, float(note.end_time) - float(note.start_time))
        reply.append(
            DialogueNote(
                note=int(note.pitch),
                velocity=int(note.velocity),
                time=max(0.0, start_time),
                duration=duration,
            )
        )

    reply.sort(key=lambda item: (item.time, item.note))
    return reply
