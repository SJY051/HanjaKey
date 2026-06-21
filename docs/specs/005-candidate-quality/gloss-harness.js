export const meta = {
  name: 'hanja-gloss',
  description: 'Find 훈음 (訓音) glosses for empty single-Hanja (spec 005 M2 ②) — Sonnet batches + 1 Opus verify',
  phases: [
    { title: 'Gloss', detail: 'batched 훈음 lookup (Sonnet)' },
    { title: 'Verify', detail: '1 Opus scan' },
  ],
}

const data = typeof args === 'string' ? JSON.parse(args) : (args ?? {})
const B = 90 // (reading, hanja) pairs per agent — gloss is a simple per-char lookup, so batch big

// Flatten the grouped {reading: "hanjas"} input into (reading, hanja) pairs, then chunk.
const pairs = []
for (const r of Object.keys(data)) for (const h of Array.from(data[r])) pairs.push({ reading: r, hanja: h })
const batches = []
for (let i = 0; i < pairs.length; i += B) batches.push(pairs.slice(i, i + B))
log(`${pairs.length} pairs → ${batches.length} gloss agents (${B} each)`)

const GLOSS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    results: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          reading: { type: 'string' },
          hanja: { type: 'string' },
          gloss: { type: 'string' }, // "뜻 음" for full; "" otherwise
          status: { type: 'string', enum: ['full', '미상', 'wrong_reading'] },
        },
        required: ['reading', 'hanja', 'gloss', 'status'],
      },
    },
  },
  required: ['results'],
}

function glossPrompt(batch) {
  const lines = batch.map((p) => `${p.reading} ${p.hanja}`).join('\n')
  return [
    `당신은 한국 한자(漢字) 자전에 정통한 전문가입니다. 아래 각 줄은 "한글음 한자" 쌍입니다.`,
    `각 한자가 그 음으로 읽힐 때의 표준 한국어 훈음(訓音 = 뜻+음)을 반환하세요.`,
    ``,
    lines,
    ``,
    `규칙:`,
    `- gloss 형식: "뜻 음" (예: "음 飮"→"마실 음", "한 韓"→"나라 한"). 뜻이 여럿이면 "뜻1, 뜻2 음"까지. 음은 입력의 그 음을 씁니다.`,
    `- 특정 자전을 그대로 베끼지 말고 짧은 표준 훈음을 생성하세요(2~4어절, 사실 표기).`,
    `- status: full(이 음으로 읽히고 뜻을 앎 → gloss 채움) / 미상(이 음으로 읽히나 뜻 불명 → gloss "") / wrong_reading(이 한자가 한국어에서 이 음으로는 사실상 안 읽힘, 본음이 따로 있음 → gloss "").`,
    `  wrong_reading 예: "교 酵"(본음 효), "시 十"(본음 십), "방 棒"(본음 봉).`,
    `- 모호하면 web_search로 확인 후 판단; 그래도 모르면 미상.`,
    `- 입력의 모든 쌍을 빠짐없이, reading·hanja를 입력 그대로 반환하세요(추가·병합·중복 금지).`,
  ].join('\n')
}

phase('Gloss')
const res = (
  await parallel(
    batches.map((b) => () =>
      agent(glossPrompt(b), {
        label: `gloss:${b[0].reading}+${b.length}`,
        phase: 'Gloss',
        schema: GLOSS_SCHEMA,
        model: 'sonnet',
      }),
    ),
  )
).filter(Boolean)
const combined = res.flatMap((r) => r.results)

const VERIFY_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    issues: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          reading: { type: 'string' },
          hanja: { type: 'string' },
          problem: { type: 'string' },
          suggest: { type: 'string' },
        },
        required: ['reading', 'hanja', 'problem'],
      },
    },
    summary: { type: 'string' },
  },
  required: ['issues', 'summary'],
}

phase('Verify')
const verifyPrompt = [
  `한국 한자 자전 검수자로서, 아래 (reading, hanja, gloss, status) 결과에서 명백한 오류만 골라내세요:`,
  `- gloss의 음이 reading과 불일치, 뜻이 명백히 틀림, full인데 비표준/엉뚱한 훈, wrong_reading 오판정 또는 놓친 것.`,
  `문제 없으면 issues=[]. 결과(JSON):`,
  JSON.stringify(combined),
].join('\n')
const verify = (
  await parallel(
    [1].map((i) => () =>
      agent(verifyPrompt, { label: `verify:${i}`, phase: 'Verify', schema: VERIFY_SCHEMA, model: 'opus' }),
    ),
  )
).filter(Boolean)

return { combined, verify }
