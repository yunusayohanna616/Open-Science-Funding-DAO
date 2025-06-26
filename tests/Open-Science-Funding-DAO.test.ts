import { assert, assertEquals, assertStringIncludes } from 'chai';
import { Client, Provider, ProviderRegistry, Result } from '@blockstack/clarity';
import { describe, it, before } from 'mocha';

describe('open-science-funding-dao contract test suite', () => {
  let client: Client;
  let provider: Provider;

  before(async () => {
    provider = await ProviderRegistry.createProvider();
    client = new Client("./contracts/open-science-funding-dao.clar");
  });

  describe('proposal creation and funding', () => {
    it('should create a new proposal', async () => {
      const result = await client.createProposal("Research Project", 1000, 3);
      assertEquals(result.success, true);
    });

    it('should allow staking tokens', async () => {
      const result = await client.stakeTokens(1, 500);
      assertEquals(result.success, true);
    });

    it('should complete milestones', async () => {
      const result = await client.completeMilestone(1, 0);
      assertEquals(result.success, true);
    });
  });
});
