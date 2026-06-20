export const meta = {
  name: 'hanja-rank-batch',
  description: 'Rank/tier single-Hanja candidates (spec 005 M2) — balanced agents + 2 Opus verifiers',
  phases: [
    { title: 'Rank', detail: 'tier 0-3 + rank, balanced agents (Sonnet)' },
    { title: 'Verify', detail: '2 parallel Opus verifiers' },
  ],
}

const data = typeof args === 'string' ? JSON.parse(args) : (args ?? {})
const T = 80 // target candidates per rank agent — big readings go solo, small ones are grouped

const entries = Object.keys(data).map((r) => ({ reading: r, list: Array.from(data[r]) }))
entries.sort((a, b) => b.list.length - a.list.length)
const groups = []
let cur = [], curN = 0
for (const e of entries) {
  if (e.list.length >= T) { groups.push([e]); continue }
  if (cur.length && curN + e.list.length > T) { groups.push(cur); cur = []; curN = 0 }
  cur.push(e); curN += e.list.length
}
if (cur.length) groups.push(cur)
log(`${entries.length} readings → ${groups.length} rank agents (target ${T} chars each)`)

const RANK_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    results: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      properties: {
        reading: { type: 'string' },
        ranked: { type: 'array', items: {
          type: 'object', additionalProperties: false,
          properties: {
            hanja: { type: 'string' },
            tier: { type: 'integer', minimum: 0, maximum: 3 },
            rank: { type: 'integer', minimum: 1 },
            reason: { type: 'string' },
          },
          required: ['hanja', 'tier', 'rank'],
        } },
      },
      required: ['reading', 'ranked'],
    } },
  },
  required: ['results'],
}

function rankPrompt(group) {
  const blocks = group.map((e) => `[음 "${e.reading}"] (${e.list.length}자): ${e.list.join(' ')}`).join('\n\n')
  return [
    `당신은 한국어와 한자(漢字)에 정통한 전문가입니다. 아래 각 한글 음에 대한 한자 후보들을 현대 한국어 사용 기준으로 평가하세요.`,
    ``,
    blocks,
    ``,
    `각 음마다, 그 음의 모든 한자에 대해 반환:`,
    `- tier: 0=일상(흔히 씀) · 1=가끔(알려졌으나 드묾) · 2=희귀·전문(고전/전문어) · 3=변이·유령·미사용(간체자·이체자·동자/약자/속자, 또는 한국어에서 사실상 안 쓰는 글자).`,
    `- rank: 그 음 안에서 현대 한국어 사용 빈도 순위(1=가장 흔함), 동률 없이 1..N.`,
    `- 간체자(简体)·이체자·이형동자(同字/略字/俗字)는 tier 3으로 강등하고 정자(正字)를 우선하세요.`,
    `- reason(선택): 판단/강등 근거 한 줄.`,
    ``,
    `각 음의 한자를 하나도 빠뜨리지 말고 모두 반환하세요(누락 금지). 입력에 있는 글자를 그대로, 정확히 한 번씩만 — 글자를 병합("A/B")하거나 새 글자를 추가하거나 중복 출력하지 마세요.`,
  ].join('\n')
}

phase('Rank')
const rankRes = (await parallel(groups.map((g) => () =>
  agent(rankPrompt(g), {
    label: `rank:${g.map((e) => e.reading).join('')}`,
    phase: 'Rank', schema: RANK_SCHEMA, model: 'sonnet',
  })
))).filter(Boolean)
const combined = rankRes.flatMap((r) => r.results)

const VERIFY_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    issues: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      properties: {
        reading: { type: 'string' },
        hanja: { type: 'string' },
        kind: { type: 'string', enum: ['wrong_tier', 'wrong_rank', 'missing', 'other'] },
        detail: { type: 'string' },
      },
      required: ['reading', 'hanja', 'kind', 'detail'],
    } },
    summary: { type: 'string' },
  },
  required: ['issues', 'summary'],
}

phase('Verify')
const verifyPrompt = [
  `한국어·한자 검수자로서, 아래 한자 후보 티어/순위 결과에서 명백한 오류만 골라내세요:`,
  `- 흔한 상용자가 잘못 강등됨(낮은 티어여야 하는데 높은 티어/순위).`,
  `- 간체자/이체자/동자인데 tier 3으로 강등되지 않음.`,
  `- 누락되거나 중복된 한자.`,
  `문제 없으면 issues=[]. 결과(JSON):`,
  JSON.stringify(combined),
].join('\n')
const verify = (await parallel([1, 2].map((i) => () =>
  agent(verifyPrompt, { label: `verify:${i}`, phase: 'Verify', schema: VERIFY_SCHEMA, model: 'opus' })
))).filter(Boolean)

return { combined, verify }
