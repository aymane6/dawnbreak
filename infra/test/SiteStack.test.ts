import { App } from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { SiteStack } from '../src/stacks/SiteStack';

test('snapshot', () => {
  const app = new App();
  const stack = new SiteStack(app, 'Site', {
    env: { account: '123456789012', region: 'us-east-1' },
    domainName: 'dawnbreak.app',
    hostedZoneId: 'Z01978801VH16H8J00TJR',
    contentPath: '../docs',
  });
  const template = Template.fromStack(stack);

  // The three URLs the App Store listing and the paywall link. Printed by the stack so a deploy
  // ends by showing what a reviewer will open.
  const outputs = template.toJSON().Outputs;
  expect(outputs.SiteUrl.Value).toBe('https://dawnbreak.app/');
  expect(outputs.PrivacyUrl.Value).toBe('https://dawnbreak.app/privacy');
  expect(outputs.TermsUrl.Value).toBe('https://dawnbreak.app/terms');

  expect(template.toJSON()).toMatchSnapshot();
});
