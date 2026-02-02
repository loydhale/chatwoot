/**
 * Auto-tagging engine for DeskFlows conversations.
 * Scans incoming message content for keywords and automatically
 * applies labels to the conversation.
 */

const AUTO_TAG_RULES = [
  {
    label: 'billing',
    keywords: [
      'bill',
      'billing',
      'invoice',
      'payment',
      'charge',
      'charged',
      'refund',
      'credit card',
      'insurance',
      'copay',
      'co-pay',
      'deductible',
      'receipt',
      'statement',
      'balance',
      'owe',
      'price',
      'cost',
      'fee',
      'expensive',
      'overcharged',
      'double charged',
      'transaction',
      'pay',
      'paid',
    ],
    color: '#F59E0B', // amber
    priority: 2,
  },
  {
    label: 'appointment',
    keywords: [
      'appointment',
      'schedule',
      'scheduling',
      'book',
      'booking',
      'reschedule',
      'cancel appointment',
      'availability',
      'available',
      'slot',
      'time slot',
      'visit',
      'come in',
      'check-in',
      'checkin',
      'walk-in',
      'walkin',
      'next available',
      'earliest',
      'opening',
    ],
    color: '#3B82F6', // blue
    priority: 1,
  },
  {
    label: 'membership',
    keywords: [
      'membership',
      'member',
      'subscribe',
      'subscription',
      'plan',
      'upgrade',
      'downgrade',
      'cancel membership',
      'renew',
      'renewal',
      'benefits',
      'tier',
      'credits',
      'points',
      'loyalty',
      'VIP',
      'premium',
      'package',
      'monthly',
      'annual',
    ],
    color: '#8B5CF6', // purple
    priority: 3,
  },
  {
    label: 'complaint',
    keywords: [
      'complaint',
      'complain',
      'upset',
      'angry',
      'furious',
      'terrible',
      'horrible',
      'worst',
      'awful',
      'disappointed',
      'disappointing',
      'unacceptable',
      'disgusted',
      'rude',
      'unprofessional',
      'poor service',
      'bad experience',
      'never coming back',
      'want to speak to manager',
      'manager',
      'supervisor',
      'escalate',
      'report',
      'not happy',
      'dissatisfied',
      'frustrated',
      'ridiculous',
    ],
    color: '#EF4444', // red
    priority: 0, // highest priority — handle complaints fast
  },
  {
    label: 'new-patient',
    keywords: [
      'new patient',
      'first time',
      'first visit',
      'never been',
      'new here',
      'just moved',
      'looking for a',
      'accepting new',
      'new client',
      'getting started',
      'sign up',
      'register',
      'registration',
    ],
    color: '#10B981', // green
    priority: 4,
  },
  {
    label: 'urgent',
    keywords: [
      'urgent',
      'emergency',
      'asap',
      'immediately',
      'right away',
      'critical',
      'severe',
      'pain',
      'bleeding',
      'allergic reaction',
      "can't breathe",
      'chest pain',
      'help now',
    ],
    color: '#DC2626', // dark red
    priority: -1, // absolute highest
  },
];

/**
 * Analyze message text and return matching auto-tag labels.
 * Returns array sorted by priority (lowest = most important).
 *
 * @param {string} messageText - The message content to analyze
 * @returns {Array<{label: string, color: string, priority: number, matchedKeywords: string[]}>}
 */
export const detectAutoTags = messageText => {
  if (!messageText || typeof messageText !== 'string') return [];

  const text = messageText.toLowerCase();
  const matches = [];

  AUTO_TAG_RULES.forEach(rule => {
    const matchedKeywords = rule.keywords.filter(keyword =>
      text.includes(keyword.toLowerCase())
    );

    if (matchedKeywords.length > 0) {
      matches.push({
        label: rule.label,
        color: rule.color,
        priority: rule.priority,
        matchedKeywords,
        confidence: matchedKeywords.length / rule.keywords.length,
      });
    }
  });

  // Sort by priority (lowest = most important), then by confidence (highest first)
  return matches.sort((a, b) => {
    if (a.priority !== b.priority) return a.priority - b.priority;
    return b.confidence - a.confidence;
  });
};

/**
 * Get only the label names from detected tags
 */
export const getAutoTagLabels = messageText => {
  return detectAutoTags(messageText).map(t => t.label);
};

/**
 * Check if a specific tag should be applied
 */
export const shouldApplyTag = (messageText, tagName) => {
  return detectAutoTags(messageText).some(t => t.label === tagName);
};

/**
 * Get all available auto-tag rules (for admin config UI)
 */
export const getAutoTagRules = () => AUTO_TAG_RULES;

export default {
  detectAutoTags,
  getAutoTagLabels,
  shouldApplyTag,
  getAutoTagRules,
  AUTO_TAG_RULES,
};
