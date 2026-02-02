import { useBranding } from '../useBranding';
import { useMapGetter } from 'dashboard/composables/store.js';

// Mock the store composable
vi.mock('dashboard/composables/store.js', () => ({
  useMapGetter: vi.fn(),
}));

describe('useBranding', () => {
  let mockGlobalConfig;

  beforeEach(() => {
    mockGlobalConfig = {
      value: {
        installationName: 'MyCompany',
      },
    };

    useMapGetter.mockReturnValue(mockGlobalConfig);
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  describe('replaceInstallationName', () => {
    it('should replace "DeskFlows" with installation name when both text and installation name are provided', () => {
      const { replaceInstallationName } = useBranding();
      const result = replaceInstallationName('Welcome to DeskFlows');

      expect(result).toBe('Welcome to MyCompany');
    });

    it('should replace multiple occurrences of "DeskFlows"', () => {
      const { replaceInstallationName } = useBranding();
      const result = replaceInstallationName(
        'DeskFlows is great! Use DeskFlows today.'
      );

      expect(result).toBe('MyCompany is great! Use MyCompany today.');
    });

    it('should return original text when installation name is not provided', () => {
      mockGlobalConfig.value = {};

      const { replaceInstallationName } = useBranding();
      const result = replaceInstallationName('Welcome to DeskFlows');

      expect(result).toBe('Welcome to DeskFlows');
    });

    it('should return original text when globalConfig is not available', () => {
      mockGlobalConfig.value = undefined;

      const { replaceInstallationName } = useBranding();
      const result = replaceInstallationName('Welcome to DeskFlows');

      expect(result).toBe('Welcome to DeskFlows');
    });

    it('should return original text when text is empty or null', () => {
      const { replaceInstallationName } = useBranding();

      expect(replaceInstallationName('')).toBe('');
      expect(replaceInstallationName(null)).toBe(null);
      expect(replaceInstallationName(undefined)).toBe(undefined);
    });

    it('should handle text without "DeskFlows" gracefully', () => {
      const { replaceInstallationName } = useBranding();
      const result = replaceInstallationName('Welcome to our platform');

      expect(result).toBe('Welcome to our platform');
    });

    it('should be case-sensitive for "DeskFlows"', () => {
      const { replaceInstallationName } = useBranding();
      const result = replaceInstallationName(
        'Welcome to deskflows and DESKFLOWS'
      );

      expect(result).toBe('Welcome to deskflows and DESKFLOWS');
    });

    it('should handle special characters in installation name', () => {
      mockGlobalConfig.value = {
        installationName: 'My-Company & Co.',
      };

      const { replaceInstallationName } = useBranding();
      const result = replaceInstallationName('Welcome to DeskFlows');

      expect(result).toBe('Welcome to My-Company & Co.');
    });
  });
});
