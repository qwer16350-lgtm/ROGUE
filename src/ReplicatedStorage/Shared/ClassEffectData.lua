-- Baseline class combat modifiers (Guardian / Slayer / Lancer). Detection lives in ClassRuleData + BuildTagService.

local ClassEffectData = {}

ClassEffectData.GuardianDamageTakenMultiplier = 0.7
ClassEffectData.SlayerSweepBaseDamageMultiplier = 1.3
ClassEffectData.LancerAttackIntervalSecondsMultiplier = 0.8

ClassEffectData.DefaultDamageTakenMultiplier = 1.0
ClassEffectData.DefaultSweepBaseDamageMultiplier = 1.0
ClassEffectData.DefaultAttackIntervalSecondsMultiplier = 1.0

return ClassEffectData
