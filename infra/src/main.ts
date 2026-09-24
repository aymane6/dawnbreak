import { App } from 'aws-cdk-lib';
import { DnsStack } from './stacks/DnsStack';
import { SiteStack } from './stacks/SiteStack';

/**
 * The pages behind dawnbreak.app.
 *
 * One environment, named explicitly rather than left to whatever profile is in the shell: a stack
 * that resolves its own account is a stack that can be deployed into the wrong one.
 *
 * `us-east-1` for both, because a CloudFront certificate can live nowhere else and splitting the
 * certificate into its own region buys a cross-region reference for no benefit here.
 */
const ENVIRONMENT = { account: '819569391684', region: 'us-east-1' };
const DOMAIN_NAME = 'dawnbreak.app';

/**
 * The zone id, filled in from `DnsStack`'s output after the first deploy.
 *
 * Written down rather than looked up at synth time on purpose: `HostedZone.fromLookup` needs
 * credentials to synthesise at all, which would mean the tests and `cdk diff` could not run without
 * them. The id never changes for the life of the zone.
 */
const HOSTED_ZONE_ID = 'Z01978801VH16H8J00TJR' as const;

const app = new App();

new DnsStack(app, 'DawnbreakDns', {
  env: ENVIRONMENT,
  domainName: DOMAIN_NAME,
  description: 'The hosted zone for dawnbreak.app, delegated from OVH',
});

new SiteStack(app, 'DawnbreakSite', {
  env: ENVIRONMENT,
  domainName: DOMAIN_NAME,
  hostedZoneId: HOSTED_ZONE_ID,
  contentPath: '../docs',
  description: 'The privacy policy, terms and support pages the App Store listing links',
});

app.synth();
