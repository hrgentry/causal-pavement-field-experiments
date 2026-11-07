# 申请 Zenodo DOI：操作清单

状态：**待合作者办理**。本文件只说明步骤和待定事项，不代表已经申请。

## 为什么需要

CBM 稿件把本仓库列为数据与代码来源（参考文献 [62]）。目前那条参考文献的作者写的是 GitHub 用户名 `hrgentry`，链接是 GitHub 发布页，没有 DOI。审稿人建议改用带 DOI 的存档。GitHub 发布页可以被修改或删除，Zenodo 存档则是固定的，并有 DOI 可以引用。

## 先由作者决定的三件事

这三件事都会写进 DOI 记录，**发布后不能撤回**，所以要先定好再申请：

1. **署名（creators）**：用论文作者姓名和单位，还是维持仓库维护者账号。目前 `CITATION.cff` 和 `RIGHTS.md` 都写明维护者账号不等于作者声明。
2. **许可（license）**：目前 `RIGHTS.md` 写明“不授予总体许可”。Zenodo 要求选一种许可或访问方式。如果仍不授予许可，可以选受限访问（restricted），或者在说明中注明“All rights reserved”。注意 LTPP 来源数据受 FHWA 条款约束，不要选择超出原有权利的许可。
3. **版本**：Zenodo 的 GitHub 集成**只存档启用之后新发布的 Release**，已有的 `v5b-20261017` 不会被自动存档。可以二选一：
   - 启用集成后，用同样的内容再发一个 Release，例如 `v5b-20261017-zenodo`，内容和哈希不变；
   - 或者在 Zenodo 网页上手动上传 `pavement-causal-appraisal-v5b-20261017.zip` 和 `SHA256SUMS.txt`。这样版本号可以保持原样，更适合需要哈希和稿件一致的情况。

## 办理步骤（手动上传方式）

1. 登录 <https://zenodo.org>，点 New upload。
2. 上传 Release 页面上的完整压缩包和 `SHA256SUMS.txt`。上传前核对压缩包的 SHA-256 与 `SHA256SUMS.txt` 一致。
3. 填写元数据：
   - Resource type：Dataset
   - Title：`Derived records, models and reproducibility materials for causal appraisal of asphalt pavement field experiments`
   - Version：`v5b-20261017`
   - Creators、License：按上面第 1、2 条的决定填写
   - Related identifiers：`https://github.com/hrgentry/causal-pavement-field-experiments/releases/tag/v5b-20261017`，关系选 *is identical to*
4. 先点 Reserve DOI 预留编号，确认无误后再 Publish。

## 拿到 DOI 后要改的地方

在这个仓库：

- `CITATION.cff`：加 `doi:` 字段，按决定更新 `authors`。
- `release-metadata.json`：把 `"doi": null` 改成实际 DOI。
- `README.md` 末尾：删掉 “No blanket license or DOI is assigned” 中关于 DOI 的部分，并加上 DOI 链接。

在论文仓库（Papers）：

- CBM v15 `working-source/references.bib` 中的 `hrgentry2026PavementDataCode`：把作者改为决定的署名，加上 `doi`，并把 `publisher` 改为 Zenodo；然后重新编译并跑交付校验。
