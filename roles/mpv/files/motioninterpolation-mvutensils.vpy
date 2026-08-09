# vim: set ft=python:

"""Real-time motion interpolation for mpv using MVUtensils."""

from fractions import Fraction
from math import ceil, isfinite

import vapoursynth as vs
from vapoursynth import core

# MVUtensils: https://github.com/myrsloik/mvutensils
# mpv VapourSynth variables:
# https://mpv.io/manual/master/#video-filters-vapoursynth

# Keep the motion-compensated rate reasonable. The chosen output rate is an
# exact divisor of the display refresh rate, so mpv can repeat every generated
# frame an integer number of times instead of interpolating all the way to the
# display rate.
MAX_OUTPUT_FPS = Fraction(60, 1)
MAX_INTERPOLATION_FACTOR = Fraction(3, 1)
MIN_INTERPOLATION_GAIN = Fraction(101, 100)
MIN_SOURCE_FPS = Fraction(10, 1)

# The balanced preset targets up to QHD on the current Ryzen 5 5600X.
# UHD is intentionally passed through because it cannot be processed reliably
# in real time with these settings.
MAX_PIXELS = 2560 * 1440
BLOCK_SIZE = 16
BLOCK_OVERLAP = 4

# Use the upstream scene-change defaults to avoid mistaking normal motion for
# a cut. blend=False below repeats a source frame at a real cut instead of
# creating a ghosted cross-fade.
SCENE_CHANGE_SAD = 400
SCENE_CHANGE_PERCENTAGE = 51.0

# False is the balanced setting. True improves some occlusions at a noticeable
# CPU cost.
EXTRA_OCCLUSION_MASK = False

MAX_RATE_DENOMINATOR = 10_000
MAX_RATE_COMPONENT = 2_147_483_647
MAX_REASONABLE_FPS = 1_000.0


def log(message):
    print(f"[motioninterpolation] {message}")


def parse_rate(value, name):
    """Return a small, mpv-safe rational rate or None for invalid metadata."""
    try:
        numeric_value = float(value)
    except (TypeError, ValueError, OverflowError):
        log(f"invalid {name}={value!r}; interpolation disabled")
        return None

    if not isfinite(numeric_value) or not 0 < numeric_value <= MAX_REASONABLE_FPS:
        log(f"invalid {name}={numeric_value!r}; interpolation disabled")
        return None

    rate = Fraction(str(numeric_value)).limit_denominator(MAX_RATE_DENOMINATOR)
    if (
        rate.numerator > MAX_RATE_COMPONENT
        or rate.denominator > MAX_RATE_COMPONENT
    ):
        log(f"unsafe {name}={rate}; interpolation disabled")
        return None

    return rate


def supported_format(clip):
    """Whether MVUtensils can process the constant clip format safely."""
    fmt = clip.format
    if fmt is None:
        return False

    if fmt.color_family not in (vs.GRAY, vs.YUV):
        return False

    if fmt.sample_type == vs.INTEGER:
        if not 8 <= fmt.bits_per_sample <= 16:
            return False
    elif fmt.sample_type == vs.FLOAT:
        if fmt.bits_per_sample != 32:
            return False
    else:
        return False

    # Supported YUV layouts: 4:4:4, 4:2:2, 4:4:0 and 4:2:0.
    return fmt.color_family != vs.YUV or (
        fmt.subsampling_w <= 1 and fmt.subsampling_h <= 1
    )


def target_rate(source_rate, display_rate):
    """Choose an exact display divisor within the CPU and ratio limits."""
    rate_cap = min(MAX_OUTPUT_FPS, source_rate * MAX_INTERPOLATION_FACTOR)
    repetitions = max(1, ceil(display_rate / rate_cap))
    return display_rate / repetitions, repetitions


def build_output(clip):
    source_rate = parse_rate(globals().get("container_fps"), "container_fps")
    display_rate = parse_rate(globals().get("display_fps"), "display_fps")

    # Passing the original mpv source through preserves its real frame
    # durations. In particular, do not call AssumeFPS on any skip path.
    if source_rate is None or display_rate is None:
        return clip

    if source_rate < MIN_SOURCE_FPS:
        log(f"source rate {float(source_rate):.3f} fps is too low; passing through")
        return clip

    pixel_count = clip.width * clip.height
    if pixel_count > MAX_PIXELS:
        log(f"{clip.width}x{clip.height} exceeds the QHD limit; passing through")
        return clip

    if not supported_format(clip):
        format_name = clip.format.name if clip.format is not None else "variable"
        log(f"unsupported format {format_name}; passing through")
        return clip

    output_rate, repetitions = target_rate(source_rate, display_rate)
    if output_rate < source_rate * MIN_INTERPOLATION_GAIN:
        log(
            f"target {float(output_rate):.3f} fps provides no meaningful "
            "increase; passing through"
        )
        return clip

    if (
        output_rate.numerator > MAX_RATE_COMPONENT
        or output_rate.denominator > MAX_RATE_COMPONENT
    ):
        log(f"unsafe output rate {output_rate}; passing through")
        return clip

    if not hasattr(core, "mvu"):
        raise RuntimeError(
            "MVUtensils is unavailable; install vapoursynth-plugin-mvutensils"
        )

    # mpv's source node has no declared FPS. Use a reduced fraction so the
    # _DurationNum/_DurationDen frame properties stay within mpv's int32 path.
    timed_clip = core.std.AssumeFPS(
        clip,
        fpsnum=source_rate.numerator,
        fpsden=source_rate.denominator,
    )

    super_clip = core.mvu.Super(
        timed_clip,
        blksize=BLOCK_SIZE,
        overlap=BLOCK_OVERLAP,
        pel=2,
    )
    vectors = core.mvu.AnalyseMany(
        super_clip,
        search=2,  # Hexagon search in MVUtensils.
        searchparam=2,
        chroma=False,
    )
    output = core.mvu.FlowFPS(
        timed_clip,
        super_clip,
        vectors,
        num=output_rate.numerator,
        den=output_rate.denominator,
        extramask=EXTRA_OCCLUSION_MASK,
        blend=False,
        thscd1=SCENE_CHANGE_SAD,
        thscd2=SCENE_CHANGE_PERCENTAGE,
    )

    log(
        f"interpolating {float(source_rate):.3f} -> {float(output_rate):.3f} "
        f"fps at {clip.width}x{clip.height} "
        f"(display {float(display_rate):.3f} Hz / {repetitions})"
    )
    return output


if "video_in" not in globals():
    raise RuntimeError("this script must be loaded by mpv's vapoursynth filter")

build_output(video_in).set_output()
