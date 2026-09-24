import { App } from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { DnsStack } from '../src/stacks/DnsStack';

const ENVIRONMENT = { account: '123456789012', region: 'us-east-1' };

test('the hosted zone and its name servers are the whole stack', () => {
  const app = new App();
  const stack = new DnsStack(app, 'Dns', { env: ENVIRONMENT, domainName: 'dawnbreak.app' });
  const template = Template.fromStack(stack);

  // The trailing dot is CloudFormation's, not ours: a zone name without it is a different zone.
  template.hasResourceProperties('AWS::Route53::HostedZone', { Name: 'dawnbreak.app.' });
  template.resourceCountIs('AWS::Route53::HostedZone', 1);
  // Everything else in this stack would be something the registrar cannot use yet.
  template.resourceCountIs('AWS::Route53::RecordSet', 0);
  expect(template.toJSON().Outputs).toHaveProperty('NameServers');
  expect(template.toJSON().Outputs).toHaveProperty('HostedZoneId');
});

test('snapshot', () => {
  const app = new App();
  const stack = new DnsStack(app, 'Dns', { env: ENVIRONMENT, domainName: 'dawnbreak.app' });
  expect(Template.fromStack(stack).toJSON()).toMatchSnapshot();
});
