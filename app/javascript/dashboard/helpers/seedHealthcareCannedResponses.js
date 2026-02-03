/**
 * Seeds healthcare canned responses into the account.
 * Call this from Settings or on first setup.
 */
import HEALTHCARE_CANNED_RESPONSES from './healthcareCannedResponses';
import CannedResponseAPI from 'dashboard/api/cannedResponse';

export const seedHealthcareCannedResponses = async (existingResponses = []) => {
  const existingCodes = new Set(existingResponses.map(r => r.short_code));
  const toCreate = HEALTHCARE_CANNED_RESPONSES.filter(
    r => !existingCodes.has(r.short_code)
  );

  const results = { created: 0, skipped: 0, errors: [] };

  const createPromises = toCreate.map(template =>
    CannedResponseAPI.create({
      short_code: template.short_code,
      content: template.content,
    })
      .then(() => {
        results.created += 1;
      })
      .catch(error => {
        results.errors.push({ code: template.short_code, error });
      })
  );

  await Promise.all(createPromises);

  results.skipped = existingResponses.length;
  return results;
};

export default seedHealthcareCannedResponses;
