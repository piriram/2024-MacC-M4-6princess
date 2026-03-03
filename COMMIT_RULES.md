# Commit Message Rules (KR/EN Mixed)

## 1) Format
`<Type>: <Mixed summary>`

Example:
`Fix: Camera 권한 팝업 재노출 버그 수정`

Optional:
- Title only. Do not write body/footer description.

## 2) Type (English only)
- `Feat`: New feature
- `Fix`: Bug fix
- `Refactor`: Internal restructuring without behavior change
- `Docs`: Documentation only
- `Style`: Formatting/UI text/style-only changes
- `Test`: Add or update tests
- `Chore`: Build, deps, config, maintenance
- `Perf`: Performance improvement
- `CI`: CI/CD workflow changes
- `Build`: Build system/tooling changes
- `Revert`: Revert previous commit

## 3) Title Rules
- Start with one `Type` + colon (`Feat:`, `Fix:`).
- Keep one-line title concise.
- Use natural KR/EN mixed wording in a single sentence.
- Do not duplicate the same meaning in two languages.
- Prefer present tense and action-focused phrasing.

## 4) Description Policy
- No description/body/footer.
- Do not add issue refs in footer; include only in PR if needed.

## 5) Recommended Examples
- `Feat: Onboarding 스킵 버튼 추가`
- `Fix: Camera 권한 팝업 재노출 버그 수정`
- `Refactor: UploadManager retry 로직 분리`
- `Chore: SwiftLint rule 업데이트`

## 6) Team Agreement
- Group related changes into one commit when it improves review flow.
- Keep naming consistent across the repo.
