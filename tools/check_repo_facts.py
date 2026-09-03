"""Bind every number on the artwork card to the source that declares it.

The art gate settles whether the card fits its columns and matches its spec.
Whether the card is true of this suite is a different question, and this file
is where it gets answered: each row is measured again from the shader, the
manifest, the CMake script or the packaging source that declares it, and a row
that no longer agrees is a failure rather than a stale drawing nobody noticed.

Standard library only, so it runs anywhere the repository is checked out and
does not need MSVC, the Windows SDK, fxc or a graphics device.
"""
import ast
import io
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "docs" / "art" / "elder-enb.art.json"

WORDS = {
    1: "one", 2: "two", 3: "three", 4: "four", 5: "five", 6: "six",
    7: "seven", 8: "eight", 9: "nine", 10: "ten", 11: "eleven",
    12: "twelve", 13: "thirteen", 14: "fourteen", 15: "fifteen",
    16: "sixteen", 17: "seventeen", 18: "eighteen", 19: "nineteen",
}

TIERS = "config/quality-tiers.csv"
QUALITY = "shaders/elder/ElderQuality.fxh"
CAPABILITIES = "shaders/elder/ElderHostCapabilities.fxh"
PAYLOADS = "shaders/elder/ElderRuntimeParameters.fxh"
MATRIX = "cmake/CheckElderStageMatrix.cmake"
GENERATOR = "cmake/GenerateElderQualityPresets.cmake"
NATIVE_SCHEMA = "native/schema/elder-native-parameters.csv"
CONTROLLER = "native/runtime/include/elder/runtime/RenderPayloadController.hpp"
BRIDGE = "native/runtime/include/elder/runtime/ShaderParameterBridge.hpp"
PACKAGER = "scripts/package.py"
VALIDATION = "docs/release-validation.md"
BUILD_FILES = ("CMakeLists.txt", "native/CMakeLists.txt",
               "native/runtime/CMakeLists.txt")
REFUSAL_LISTS = ("FORBIDDEN_COMPONENTS", "FORBIDDEN_NAME_MARKERS",
                 "FORBIDDEN_BINARY_SUFFIXES", "FORBIDDEN_ENB_BINARY_NAMES",
                 "SECRET_PATTERNS")
FIXTURES = ("full-frame-history", "object-motion", "foreign-scratch-read",
            "scratch-as-history", "cross-effect-alpha-packing",
            "non-adaptation-texture-previous", "false-resource-declaration")


def _read(relative: str) -> str:
    """Universal newlines on purpose: this tree mixes CRLF and LF sources."""
    return io.open(ROOT / relative, encoding="utf-8").read()


def _word(count: int) -> str:
    """Spelled out, because the card draws words where it can."""
    if count not in WORDS:
        raise AssertionError(f"no word for {count}; widen WORDS or use digits")
    return WORDS[count]


def _enumerators(text: str, name: str) -> int:
    """Elder enums carry no underlying type and indent by two spaces."""
    opener = re.search(rf"enum class {name}(?: : [\w:]+)? \{{", text)
    if opener is None:
        raise AssertionError(f"enum class {name} is gone from the source")
    start = opener.end()
    body = text[start:text.index("\n};", start)]
    return len(re.findall(r"^\s{2}\w+ = [^,]+,$", body, re.MULTILINE))


def _csv_rows(relative: str) -> tuple[list[str], list[list[str]]]:
    lines = [line for line in _read(relative).splitlines() if line.strip()]
    return lines[0].split(","), [line.split(",") for line in lines[1:]]


def _tier_arms() -> list[dict[str, int]]:
    """The five preprocessor arms of the per-tier budget table."""
    quality = _read(QUALITY)
    start = quality.index("#if ELDER_QUALITY_TIER == 0")
    body = quality[start:quality.index("\n#endif", start)]
    arms = re.split(r"^#(?:elif [^\n]*|else)$", body, flags=re.MULTILINE)
    found = [dict(re.findall(r"#define (ELDER_\w+_VALUE) (\d+)", arm))
             for arm in arms]
    return [{key: int(value) for key, value in arm.items()} for arm in found]


def _block(text: str, opener: str, closer: str) -> str:
    start = text.index(opener)
    return text[start:text.index("\n", text.index(closer, start))]


def _stage_rows() -> list[str]:
    body = _block(_read(MATRIX), "set(elder_stage_rows", '")')
    return re.findall(r'"(\w+)\.fx\|\w+"', body)


def _generator_stages(generator: str) -> list[str]:
    body = _block(generator, "set(elder_stages\n", ")")
    return re.findall(r"^\s+(\w+)\.fx\)?$", body, re.MULTILINE)


def _files_per_tier(generator: str) -> int:
    """Two writes stand alone, and one is inside the per-stage loop."""
    loop = generator.index("foreach(elder_stage IN LISTS elder_stages)")
    writes = [call.start() for call in re.finditer(r"file\(WRITE ", generator)]
    if not writes:
        raise AssertionError("the generator writes no files at all now")
    outside = len([call for call in writes if call < loop])
    inside = len(writes) - outside
    return outside + inside * len(_generator_stages(generator))


def _entries(node: ast.expr) -> int:
    """How many entries a literal collection declares, however it is spelled.

    Some of these lists are written as a bare tuple and some are wrapped in
    frozenset, and the secret patterns hold compiled expressions rather than
    literals, so the entries are counted structurally rather than evaluated.
    """
    if isinstance(node, (ast.Tuple, ast.List, ast.Set)):
        return len(node.elts)
    if isinstance(node, ast.Call) and len(node.args) == 1:
        return _entries(node.args[0])
    raise AssertionError("this constant is no longer a literal collection")


def _constant(name: str) -> int:
    """A module constant of scripts/package.py, read as a value not a line."""
    for node in ast.parse(_read(PACKAGER)).body:
        targets = getattr(node, "targets", [])
        if any(getattr(target, "id", None) == name for target in targets):
            return _entries(node.value)
    raise AssertionError(f"{name} is gone from {PACKAGER}")


def _add_tests() -> list[str]:
    """Every declared CTest name, however the call is wrapped."""
    names = []
    for relative in BUILD_FILES:
        text = _read(relative)
        for call in re.finditer(r"add_test\(", text):
            window = text[call.end():call.end() + 240]
            name = re.search(r"NAME\s+([A-Za-z_0-9]+)", window)
            if name is None:
                raise AssertionError(f"an add_test in {relative} names nothing")
            names.append(name.group(1))
    return names


def _acceptance() -> str:
    validation = _read(VALIDATION)
    pending = "results remain pending" in validation.replace("\n", " ")
    return "none in the tree" if pending else "recorded in the tree"


def measure() -> dict[str, str]:
    """Every card value, rebuilt from the source rather than from the card."""
    columns, rows = _csv_rows(TIERS)
    matrix = _read(MATRIX)
    capabilities = _read(CAPABILITIES)
    generator = _read(GENERATOR)
    tiers = int(re.search(r"foreach\(tier RANGE 0 (\d+)\)", matrix).group(1)) + 1
    refusals = matrix.count('expect_elder_stage_rejection("')
    refusals += matrix.count("expect_elder_synthesized_vertex_rejection(")
    rules = sum(_constant(name) for name in REFUSAL_LISTS)

    return {
        "quality tiers": f"{_word(len(rows))} of them",
        "tier knobs": f"{_word(len(columns) - 3)} per tier",
        "generated per tier": f"{_word(_files_per_tier(generator))} files",
        "compile matrix": f"{tiers * len(_stage_rows())} compilations",
        "refusal fixtures": f"{_word(refusals)} must fail",
        "stage declarations":
            f"{_word(capabilities.count('#ifndef ELDER_STAGE_'))} required",
        "capability rungs":
            f"{_word(capabilities.count('#define ELDER_CAPABILITY_'))} of them",
        "native parameters": f"{_word(len(_csv_rows(NATIVE_SCHEMA)[1]))} rows",
        "runtime payloads":
            f"{_word(_read(PAYLOADS).count('UIHidden = 1'))} float4 keys",
        "payload phases":
            f"{_word(_enumerators(_read(CONTROLLER), 'RenderPayloadPhase'))}"
            " of them",
        "package refusal rules": f"{rules} of them",
        "ctest targets": f"{len(_add_tests())} declared",
        "live acceptance recorded": _acceptance(),
    }


def check_card_rows_match_the_source() -> list[str]:
    card = json.load(io.open(SPEC, encoding="utf-8"))["cards"][0]
    drawn = {field["key"]: field["value"] for field in card["fields"]}
    measured = measure()
    bad = []
    for key, value in sorted(measured.items()):
        if key not in drawn:
            bad.append(f"the card no longer has a {key!r} row")
        elif drawn[key] != value:
            bad.append(f"{key}: the card says {drawn[key]!r}, "
                       f"the source says {value!r}")
    for key in sorted(set(drawn) - set(measured)):
        bad.append(f"{key!r} is drawn but nothing measures it")
    return bad


def check_the_counters_are_read_not_guessed() -> list[str]:
    """A regex that matches nothing reports zero and passes every row.

    So each parser is aimed at a shape it must refuse. If somebody reformats
    an enum, renames a refusal list or drops the per-stage write loop, this
    fails before the card does.
    """
    bad = []
    try:
        _enumerators(_read(CONTROLLER), "NoSuchEnumExists")
    except AssertionError:
        pass
    else:
        bad.append("a missing enum was counted instead of refused")
    try:
        _constant("NoSuchListExists")
    except AssertionError:
        pass
    else:
        bad.append("a missing refusal list was counted instead of refused")
    if _enumerators(_read(BRIDGE), "ShaderParameterBridgeCode") != 5:
        bad.append("ShaderParameterBridgeCode no longer reads as five codes")
    if _enumerators(_read(CONTROLLER), "RenderPayloadResultCode") != 7:
        bad.append("RenderPayloadResultCode no longer reads as seven codes")
    if len(_add_tests()) != len(set(_add_tests())):
        bad.append("two CTest targets share a name, so the count is inflated")
    return bad


def check_the_tiers_agree_across_the_language_boundary() -> list[str]:
    """The manifest and the shader header declare the same seven budgets.

    One is a comma separated table read by CMake, the other is a chain of
    preprocessor arms read by the compiler. A change to either one alone is
    the drift worth catching, and neither file can see the other.
    """
    columns, rows = _csv_rows(TIERS)
    arms = _tier_arms()
    bad = []
    if len(arms) != len(rows):
        return [f"the manifest has {len(rows)} tiers and the shader has "
                f"{len(arms)} arms, so no row can be compared"]
    for row, arm in zip(rows, arms):
        for column, value in zip(columns[3:], row[3:]):
            macro = f"ELDER_{column.upper()}_VALUE"
            if macro not in arm:
                bad.append(f"tier {row[0]}: the shader declares no {macro}")
            elif arm[macro] != int(value):
                bad.append(f"tier {row[0]}: the manifest says {column} is "
                           f"{value} and the shader says {arm[macro]}")
    if "#error ELDER_QUALITY_TIER must be in [0,4]" not in _read(QUALITY):
        bad.append("a tier outside zero through four is no longer a "
                   "compile error, so the drawing overstates the refusal")
    return bad


def check_the_matrix_the_flow_draws_is_the_one_cmake_runs() -> list[str]:
    """The flow names nine stages, five tiers and eight refusals, by name."""
    matrix = _read(MATRIX)
    generator = _read(GENERATOR)
    bad = []
    for case in FIXTURES:
        if f'expect_elder_stage_rejection("{case}"' not in matrix:
            bad.append(f"the {case} fixture is gone from the matrix")
    if "expect_elder_synthesized_vertex_rejection(" not in matrix:
        bad.append("the synthesized vertex fixture is gone from the matrix")
    if "foreach(tier RANGE 0 4)" not in matrix:
        bad.append("the matrix no longer sweeps tiers zero through four")
    if _stage_rows() != _generator_stages(generator):
        bad.append("the stages the matrix compiles are no longer the stages "
                   "the generator writes an ini for")
    if "TECHNIQUE=1" not in generator:
        bad.append("the generated stage ini no longer sets TECHNIQUE=1, so "
                   "ENB would fall back to its own default shader")
    return bad


def check_the_marked_row_is_still_an_honest_null() -> list[str]:
    """The one toned row says no live acceptance is recorded anywhere.

    If somebody enters a live ENBSeries result, this fails, and the right
    repair is to redraw the card rather than to loosen the check.
    """
    validation = _read(VALIDATION).replace("\n", " ")
    bad = []
    if "not an in-game" not in validation:
        bad.append("the release media no longer carries its notice that the "
                   "artwork is not an in-game capture")
    if measure()["live acceptance recorded"] != "none in the tree":
        bad.append("live acceptance is recorded now, and the card still "
                   "draws this row as an honest null")
    return bad


CHECKS = (
    check_card_rows_match_the_source,
    check_the_counters_are_read_not_guessed,
    check_the_tiers_agree_across_the_language_boundary,
    check_the_matrix_the_flow_draws_is_the_one_cmake_runs,
    check_the_marked_row_is_still_an_honest_null,
)


def main() -> int:
    worst = 0
    for check in CHECKS:
        failures = check()
        name = check.__name__.removeprefix("check_")
        print(("ok   " if not failures else "FAIL ") + f"facts.{name}")
        for failure in failures:
            print(f"       {failure}")
        worst = max(worst, 1 if failures else 0)
    return worst


if __name__ == "__main__":
    raise SystemExit(main())
