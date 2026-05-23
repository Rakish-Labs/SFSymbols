# SFSymbols — Features Added After the Fork

The fork's premise was unchanged from upstream SFSafeSymbols: type-safe access to SF Symbols so consumers write `.circleFill` instead of the stringly-typed `UIImage(systemName: "circle.fill")`. What the fork adds is **rich, queryable metadata about each symbol**, plus a better authoring/discovery experience. Everything below is metadata Apple ships in the SF Symbols app but that upstream did not surface programmatically.

A cross-cutting requirement: every piece of metadata must be reachable **both** from the static type-safe accessor (`SFSymbol.heartFill`) **and** from a symbol constructed at runtime from a raw string (`SFSymbol(rawValue: "heart.fill")`), and the two must agree. Metadata is read-only and derived from the symbol's identity.

## 1. Categories

**Value:** Consumers can build symbol pickers, filter palettes, or group symbols by Apple's own taxonomy (Communication, Weather, Health, etc.) without hand-maintaining their own mapping.

Requirements:
- Each symbol exposes the set of categories it belongs to. A symbol can belong to multiple categories (e.g. a quote bubble is in Accessibility, Communication, and Multicolor) or to none.
- A convenience predicate answers "is this symbol in category X?"
- The full set of categories is enumerable (so a UI can list every category), and the category names match Apple's set (~29 categories including the special `multicolor`, `variable`, `whatsnew`).
- Categories must be a closed, known set the consumer can `switch` over exhaustively.

## 2. Restrictions

**Value:** Some symbols are legally/brand restricted — they may only represent specific Apple products/features and must not be restyled. Consumers (especially those building general-purpose pickers) need to detect these to avoid misuse and App Store rejection.

Requirements:
- Each symbol exposes whether it carries a usage restriction (a simple boolean is sufficient for the common case).
- The semantics should be documented: restricted symbols may not be modified and only refer to specific Apple products/features.

## 3. Search Keywords

**Value:** Apple associates search terms with symbols (e.g. `magnifyingglass` → "search", `cloud` → "weather"). Surfacing these lets consumers build a search box over symbols that matches how the SF Symbols app itself searches, rather than only matching literal symbol names.

Requirements:
- Each symbol exposes its set of search keywords (possibly empty).
- Keywords are consistent regardless of how the symbol was obtained.

## 4. Variant Relationships

**Value:** SF Symbols are organized as a base symbol (`heart`) with variants (`heart.fill`, `heart.circle`, `heart.slash`, …), and variants can nest (`heart.circle.fill` is the `fill` variant of `heart.circle`). Exposing this graph lets consumers do things like: show only base symbols in a picker then offer variant toggles, or resolve "the filled version of whatever symbol the user chose."

Requirements:
- A symbol exposes its immediate **base symbol** (or `nil` if it is itself a base), and its **variant type** as a string (`"fill"`, `"circle"`, `"slash"`, `"badge"`, `"square"`, `"inverse"`, `"stack"`, …).
- A symbol exposes whether it is a variant at all.
- A base symbol exposes its **direct** variants only — not transitively nested ones (`heart.variants` includes `heartCircle` but not `heartCircleFill`).
- The library exposes the set of **all base symbols** (all non-variants), and base + variant counts must partition the full symbol set with no overlap.
- **Disambiguation is a hard requirement, not a nice-to-have.** Variant detection cannot be naïve dotted-suffix splitting: `checkmark.rectangle` is a real variant of `checkmark`, but `list.bullet.below.rectangle` is a standalone base symbol despite looking decomposable. A from-scratch implementation must resolve variant relationships against actual symbol membership, not string heuristics.
- Variant data is availability-gated: which variants exist depends on the OS version at runtime, mirroring Apple's per-version availability (a variant introduced in iOS 18 must not appear on iOS 16).

## 5. Rich Quick Help Documentation

**Value:** When a developer option-clicks a symbol in Xcode, they see what the symbol actually is — without leaving the editor or opening the SF Symbols app. This turns the type-safe API into a discovery tool.

Requirements:
- Each generated symbol carries a documentation comment showing: the rendered glyph itself, a count summary, its localizations (with the OS version each localization became available), its layersets/rendering modes (hierarchical, multicolor, etc., again version-gated), and its categories.
- This documentation is generated, never hand-written, and stays in sync with the metadata above.
- (The PR that introduced this also built tooling to render symbols to PNGs for documentation; the consumer-facing payoff is the inline Quick Help, however the images are produced.)

## Non-consumer changes (context, not requirements)

- Repository renamed from **SFSafeSymbols → SFSymbols** (module, types, file names).
- Generator tooling adopted **swift-argument-parser** and other internal refactors. These don't change the public API; a from-scratch reimplementation is free to use any generation approach as long as the metadata contracts above hold.
- `Category` made `CaseIterable` (this *is* a small consumer-facing requirement — see §1).

---

The through-line for a reimplementation: the differentiator over upstream is **exposing Apple's full symbol metadata graph (categories, restrictions, keywords, variant lineage) as type-safe, runtime-queryable, availability-correct API**, plus surfacing it in Xcode Quick Help. The variant disambiguation and the static/raw-value agreement are the two requirements most likely to be gotten wrong if reimplemented casually.
