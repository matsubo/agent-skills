---
name: release
description: 汎用リリースワークフロー。バージョンbump → 変更履歴生成 → コミット → タグ → push（要ユーザー承認）→ GitHub Release。引数: patch/minor/major、または日付タグ運用のプロジェクトは引数なし。
disable-model-invocation: true
argument-hint: "[patch|minor|major]"
---

# Release Workflow

プロジェクト非依存のリリース手順。ユーザーが `/release` を実行した時点で「リリースする」意思は明示済みだが、**push だけは毎回ユーザー承認が必要**（グローバルルール）。

## Step 1: Pre-flight

1. `git branch --show-current` — main / master であること。違えば中断して確認。
2. `git status` — 未コミット変更を表示し、リリースに含めるか確認。
3. テスト実行（存在するものを順に探す）: `just test` → `bun test` → `bun run test`。失敗したら中断。どれも存在しない場合はその旨をユーザーに伝え、テストなしで続行してよいか確認。

## Step 2: バージョン決定

- `package.json` に `version` があれば `$ARGUMENTS`（patch/minor/major、デフォルト patch）で bump。
  `npm version <type> --no-git-tag-version` 相当の編集を行う。
- version フィールドがない（データ/コンテンツ系リポジトリ）場合は日付タグ `vYYYY.MM.DD` を使う（同日2回目は `-2` サフィックス）。

## Step 3: リリースノート生成

```bash
git log --pretty=format:"%s" $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD
```

Conventional Commits で分類: feat → What's New / fix → Bug Fixes / refactor・perf → Improvements / docs → Documentation / chore → Maintenance。ユーザー向けの平易な文にする。英語リポジトリは英語で。

## Step 4: コミット & タグ

1. バージョン変更をコミット: `chore: bump version to vX.Y.Z`（attribution なし — グローバル設定どおり）
2. 注釈付きタグ: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`

## Step 5: Push（ユーザー承認必須）

グローバルフックが `git push` をブロックする。**ここで必ず停止し**、ユーザーに以下を提示:

> push 準備完了: <commit> + tag vX.Y.Z。`! git push origin main --follow-tags` を実行するか、「push して」と返答してください。

ユーザーの明示承認後のみ push。承認は今回のリリース限り。

## Step 6: GitHub Release

```bash
gh release create vX.Y.Z --title "vX.Y.Z" --notes "<release notes>"
```

Release URL を報告。リモートが GitHub でない場合はこのステップをスキップし、その旨を報告。

## Step 7: デプロイ（該当時）

Coolify 管理のアプリなら deploy-verify スキルの利用を提案（自動実行はしない）。

## エラー時

失敗したステップで停止 → エラー全文表示 → 修正方法提示 → ユーザーに継続可否を確認。途中で作った tag は `git tag -d` でロールバック可能なことを伝える。
