import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure users can register in the alpha-heap health vault",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;

    let block = chain.mineBlock([
      Tx.contractCall('health-vault', 'onboard-user', [], user1.address)
    ]);

    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result, '(ok true)');

    // Verify user registration
    let userRegistration = chain.callReadOnlyFn('health-vault', 'query-user-registration', [types.principal(user1.address)], user1.address);
    assertEquals(userRegistration.result, '(ok true)');
  },
});

Clarinet.test({
  name: "Prevent duplicate user registration in alpha-heap health vault",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user1 = accounts.get('wallet_1')!;

    let block = chain.mineBlock([
      Tx.contractCall('health-vault', 'onboard-user', [], user1.address),
      Tx.contractCall('health-vault', 'onboard-user', [], user1.address)
    ]);

    assertEquals(block.receipts.length, 2);
    assertEquals(block.receipts[0].result, '(ok true)');
    assertEquals(block.receipts[1].result, '(err u2)');
  },
});

Clarinet.test({
  name: "Users can link and unlink health devices in alpha-heap system",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user1 = accounts.get('wallet_1')!;

    let block = chain.mineBlock([
      Tx.contractCall('health-vault', 'onboard-user', [], user1.address),
      Tx.contractCall('health-vault', 'link-user-device', [types.ascii('device-123'), types.ascii('fitness-tracker')], user1.address),
    ]);

    assertEquals(block.receipts.length, 2);
    assertEquals(block.receipts[1].result, '(ok true)');

    // Unlink device
    block = chain.mineBlock([
      Tx.contractCall('health-vault', 'unlink-user-device', [types.ascii('device-123')], user1.address)
    ]);

    assertEquals(block.receipts[0].result, '(ok true)');
  },
});

Clarinet.test({
  name: "Deployer can register verified data entities in alpha-heap",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const researchInstitute = accounts.get('wallet_1')!;

    let block = chain.mineBlock([
      Tx.contractCall('health-vault', 'register-data-entity', [types.principal(researchInstitute.address), types.ascii('research-org')], deployer.address)
    ]);

    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result, '(ok true)');

    // Verify entity registration
    let entityVerification = chain.callReadOnlyFn('health-vault', 'query-entity-verification', [types.principal(researchInstitute.address)], deployer.address);
    assertEquals(entityVerification.result, '(ok true)');
  },
});