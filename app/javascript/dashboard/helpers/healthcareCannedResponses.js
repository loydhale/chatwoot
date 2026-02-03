/**
 * Pre-built canned response templates for common healthcare support scenarios.
 * These are seeded into DeskFlows when the account is set up or can be
 * imported via Settings → Canned Responses.
 */

const HEALTHCARE_CANNED_RESPONSES = [
  // ── Appointment Confirmation ──────────────────────────────────
  {
    short_code: 'appt_confirm',
    content:
      'Hi {{contact.name}}! 👋 This is a confirmation for your upcoming appointment:\n\n📅 Date: {{appointment.date}}\n🕐 Time: {{appointment.time}}\n📍 Location: {{appointment.location}}\n\nPlease arrive 10-15 minutes early. If you need to reschedule, reply to this message or call us. See you soon!',
    category: 'appointment',
  },
  {
    short_code: 'appt_reminder_24h',
    content:
      'Friendly reminder! 🔔 You have an appointment tomorrow:\n\n📅 {{appointment.date}} at {{appointment.time}}\n📍 {{appointment.location}}\n\nPlease remember to:\n✅ Bring your ID and insurance card\n✅ Arrive 10 minutes early\n✅ Complete any pre-visit forms\n\nNeed to reschedule? Let us know ASAP!',
    category: 'appointment',
  },
  {
    short_code: 'appt_reminder_1h',
    content:
      "Just a heads up — your appointment is in about 1 hour! 🕐\n\n📍 {{appointment.location}}\n\nWe're looking forward to seeing you. If you're running late, please give us a call.",
    category: 'appointment',
  },
  {
    short_code: 'appt_followup',
    content:
      "Hi {{contact.name}}! Thank you for visiting us today. 🙏\n\nWe hope everything went well. If you have any questions about your visit or treatment plan, don't hesitate to reach out.\n\nYour next appointment: {{appointment.next_date}}\n\nTake care! 💙",
    category: 'appointment',
  },

  // ── Reschedule ────────────────────────────────────────────────
  {
    short_code: 'appt_reschedule',
    content:
      "No problem at all! Let's get you rescheduled. 📅\n\nHere are our next available times:\n• {{slot_1}}\n• {{slot_2}}\n• {{slot_3}}\n\nWhich works best for you? Or I can check other dates — just let me know your preference!",
    category: 'appointment',
  },
  {
    short_code: 'appt_cancel_confirm',
    content:
      "Your appointment on {{appointment.date}} has been cancelled. If you'd like to rebook, just reply here or call us anytime.\n\nWe hope to see you again soon! 😊",
    category: 'appointment',
  },
  {
    short_code: 'appt_noshow',
    content:
      "Hi {{contact.name}}, we noticed you weren't able to make your appointment today. We hope everything is okay! 💛\n\nWe'd love to get you rescheduled. Would you like to book a new time? Our next available slots are:\n• {{slot_1}}\n• {{slot_2}}\n\nJust let us know!",
    category: 'appointment',
  },

  // ── Billing ───────────────────────────────────────────────────
  {
    short_code: 'billing_inquiry',
    content:
      "Thanks for reaching out about your billing! 💳\n\nI'm looking into your account now. Could you please confirm:\n• Your full name on the account\n• Date of service in question\n• The amount or charge you have questions about\n\nI'll get back to you with the details right away.",
    category: 'billing',
  },
  {
    short_code: 'billing_payment_received',
    content:
      "Great news! ✅ We've received your payment of {{payment.amount}}.\n\nTransaction ID: {{payment.transaction_id}}\nDate: {{payment.date}}\n\nYour account is now current. If you have any questions, feel free to ask!",
    category: 'billing',
  },
  {
    short_code: 'billing_payment_failed',
    content:
      "Hi {{contact.name}}, we weren't able to process your payment of {{payment.amount}}. 😕\n\nThis could be due to:\n• Expired card on file\n• Insufficient funds\n• Bank security hold\n\nCould you please update your payment method or try again? You can update your card at: {{payment_link}}\n\nLet me know if you need help!",
    category: 'billing',
  },
  {
    short_code: 'billing_insurance',
    content:
      "Regarding your insurance inquiry:\n\nWe've submitted your claim to {{insurance.provider}}. Here's the status:\n\n📋 Claim #: {{insurance.claim_id}}\n📊 Status: {{insurance.status}}\n💰 Your estimated responsibility: {{insurance.patient_amount}}\n\nInsurance processing typically takes 2-4 weeks. We'll update you when we hear back!",
    category: 'billing',
  },
  {
    short_code: 'billing_payment_plan',
    content:
      'We totally understand — healthcare costs can add up. 💙\n\nWe offer flexible payment plans:\n• Split your balance into monthly payments\n• No interest for qualifying plans\n• Easy automatic payments\n\nYour current balance: {{billing.balance}}\n\nWould you like me to set up a payment plan? I can walk you through the options!',
    category: 'billing',
  },

  // ── Membership ────────────────────────────────────────────────
  {
    short_code: 'membership_welcome',
    content:
      "Welcome to the family, {{contact.name}}! 🎉\n\nYour {{membership.tier}} membership is now active. Here's what you get:\n\n✨ {{membership.benefit_1}}\n✨ {{membership.benefit_2}}\n✨ {{membership.benefit_3}}\n\nMember ID: {{membership.id}}\nStart Date: {{membership.start_date}}\n\nWe're thrilled to have you! Book your first session anytime.",
    category: 'membership',
  },
  {
    short_code: 'membership_renewal',
    content:
      'Hi {{contact.name}}! Your {{membership.tier}} membership is up for renewal on {{membership.renewal_date}}. 📋\n\nCurrent plan: {{membership.plan}}\nMonthly rate: {{membership.rate}}\n\nYour membership will auto-renew unless you let us know otherwise. Want to make any changes to your plan? Just reply here!',
    category: 'membership',
  },
  {
    short_code: 'membership_upgrade',
    content:
      "Great choice! 🌟 Here's what upgrading to {{membership.new_tier}} gets you:\n\n🔹 {{upgrade.benefit_1}}\n🔹 {{upgrade.benefit_2}}\n🔹 {{upgrade.benefit_3}}\n\nNew monthly rate: {{membership.new_rate}}\n(That's only {{membership.price_diff}} more per month!)\n\nWant me to process the upgrade? It takes effect immediately!",
    category: 'membership',
  },
  {
    short_code: 'membership_cancel',
    content:
      "We're sorry to see you go, {{contact.name}}. 😔\n\nBefore we process your cancellation, would you like to:\n• Pause your membership instead (up to 3 months)\n• Downgrade to a lower tier\n• Switch to a different plan\n\nIf you'd still like to cancel, your membership will remain active through {{membership.end_date}}.\n\nLet me know how you'd like to proceed.",
    category: 'membership',
  },
  {
    short_code: 'membership_benefits',
    content:
      "Here's a recap of your {{membership.tier}} membership benefits:\n\n✅ {{membership.benefit_1}}\n✅ {{membership.benefit_2}}\n✅ {{membership.benefit_3}}\n✅ {{membership.benefit_4}}\n\nCredits remaining this month: {{membership.credits}}\nNext renewal: {{membership.renewal_date}}\n\nDon't forget to use your benefits! Book your next visit today. 📅",
    category: 'membership',
  },

  // ── General Support ───────────────────────────────────────────
  {
    short_code: 'greeting',
    content:
      'Hi {{contact.name}}! 👋 Thanks for reaching out to us. How can I help you today?',
    category: 'general',
  },
  {
    short_code: 'hold_on',
    content:
      "Great question! Let me look into that for you. I'll have an answer shortly — thanks for your patience! 🙏",
    category: 'general',
  },
  {
    short_code: 'transfer_agent',
    content:
      "I'm going to connect you with a specialist who can help with this. You'll hear from them shortly. Thank you for your patience! 🤝",
    category: 'general',
  },
  {
    short_code: 'closing_resolved',
    content:
      "Glad I could help! 😊 Is there anything else you need? If not, I'll close this conversation. You can always reach out again anytime.\n\nHave a great day! 💙",
    category: 'general',
  },
  {
    short_code: 'hours_info',
    content:
      'Our hours of operation are:\n\n🕐 Monday - Friday: 8:00 AM - 6:00 PM\n🕐 Saturday: 9:00 AM - 2:00 PM\n🕐 Sunday: Closed\n\nFor after-hours emergencies, please call {{emergency_phone}}.',
    category: 'general',
  },

  // ── Complaint Handling ────────────────────────────────────────
  {
    short_code: 'complaint_ack',
    content:
      "I'm really sorry to hear about your experience, {{contact.name}}. 😞 Your feedback is incredibly important to us.\n\nI want to make sure we address this properly. Could you share a few more details about what happened? I'm here to help make this right.",
    category: 'complaint',
  },
  {
    short_code: 'complaint_escalate',
    content:
      "Thank you for sharing those details. I completely understand your frustration, and I want to make sure this gets the attention it deserves.\n\nI'm escalating this to our {{department}} team right now. You'll hear from them within {{response_time}}.\n\nReference #: {{ticket_id}}\n\nWe take this very seriously and will work to resolve it promptly. 🙏",
    category: 'complaint',
  },
  {
    short_code: 'complaint_resolved',
    content:
      "Hi {{contact.name}}, following up on your recent concern:\n\nWe've {{resolution_summary}}.\n\nI hope this resolves things for you. If you have any other concerns, please don't hesitate to reach out. Your satisfaction is our top priority. 💙\n\nThank you for your patience and for giving us the opportunity to make it right.",
    category: 'complaint',
  },
];

export default HEALTHCARE_CANNED_RESPONSES;

/**
 * Get canned responses filtered by category
 */
export const getCannedResponsesByCategory = category => {
  if (!category) return HEALTHCARE_CANNED_RESPONSES;
  return HEALTHCARE_CANNED_RESPONSES.filter(r => r.category === category);
};

/**
 * Get all available categories
 */
export const getCannedResponseCategories = () => {
  return [...new Set(HEALTHCARE_CANNED_RESPONSES.map(r => r.category))];
};

/**
 * Search canned responses by shortcode or content
 */
export const searchCannedResponses = query => {
  const q = query.toLowerCase();
  return HEALTHCARE_CANNED_RESPONSES.filter(
    r =>
      r.short_code.toLowerCase().includes(q) ||
      r.content.toLowerCase().includes(q)
  );
};
