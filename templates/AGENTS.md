# Weekly Report Command

When the user asks to generate a weekly report or summarize recent work:

1. Run: `python3 ~/.local/share/work-tracker/reporter.py concise`
   (or `detailed` mode if the user asks for more detail, or `7`/`14`/`30` for custom days)

2. Based on the raw output, produce a clean weekly report:
   - Group by project
   - Each item: 5-15 characters (Chinese) or 5-15 words (English) in concise mode
   - Include statistics footer

3. If asked in detailed mode, keep commit hashes, file change counts, and user message previews.
