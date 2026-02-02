import { buildPortalArticleURL, buildPortalURL } from '../portalHelper';

describe('PortalHelper', () => {
  describe('buildPortalURL', () => {
    it('returns the correct url', () => {
      window.deskflowsConfig = {
        hostURL: 'https://app.deskflowss.ai',
        helpCenterURL: 'https://help.deskflows.app',
      };
      expect(buildPortalURL('handbook')).toEqual(
        'https://help.deskflows.app/hc/handbook'
      );
      window.deskflowsConfig = {};
    });
  });

  describe('buildPortalArticleURL', () => {
    it('returns the correct url', () => {
      window.deskflowsConfig = {
        hostURL: 'https://app.deskflowss.ai',
        helpCenterURL: 'https://help.deskflows.app',
      };
      expect(
        buildPortalArticleURL('handbook', 'culture', 'fr', 'article-slug')
      ).toEqual('https://help.deskflows.app/hc/handbook/articles/article-slug');
      window.deskflowsConfig = {};
    });

    it('returns the correct url with custom domain', () => {
      window.deskflowsConfig = {
        hostURL: 'https://app.deskflowss.ai',
        helpCenterURL: 'https://help.deskflows.app',
      };
      expect(
        buildPortalArticleURL(
          'handbook',
          'culture',
          'fr',
          'article-slug',
          'custom-domain.dev'
        )
      ).toEqual('https://custom-domain.dev/hc/handbook/articles/article-slug');
    });

    it('handles https in custom domain correctly', () => {
      window.deskflowsConfig = {
        hostURL: 'https://app.deskflowss.ai',
        helpCenterURL: 'https://help.deskflows.app',
      };
      expect(
        buildPortalArticleURL(
          'handbook',
          'culture',
          'fr',
          'article-slug',
          'https://custom-domain.dev'
        )
      ).toEqual('https://custom-domain.dev/hc/handbook/articles/article-slug');
    });

    it('uses hostURL when helpCenterURL is not available', () => {
      window.deskflowsConfig = {
        hostURL: 'https://app.deskflowss.ai',
        helpCenterURL: '',
      };
      expect(
        buildPortalArticleURL('handbook', 'culture', 'fr', 'article-slug')
      ).toEqual('https://app.deskflowss.ai/hc/handbook/articles/article-slug');
    });
  });
});
