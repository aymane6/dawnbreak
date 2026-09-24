import { CfnOutput, Fn, Stack, StackProps } from 'aws-cdk-lib';
import { HostedZone } from 'aws-cdk-lib/aws-route53';
import { Construct } from 'constructs';

export interface DnsStackProps extends StackProps {
  /** The apex, without a trailing dot. */
  readonly domainName: string;
}

/**
 * The hosted zone, and nothing else.
 *
 * On its own stack on purpose. The domain is registered at OVH, so the zone has to exist and hand
 * back its four name servers *before* anything can be delegated to it, and the certificate in
 * `SiteStack` cannot validate until that delegation is live in public DNS. One stack that did both
 * would sit waiting for a DNS change that only a human can make at the registrar, and then roll
 * back the zone it was waiting on.
 */
export class DnsStack extends Stack {
  public readonly zone: HostedZone;

  constructor(scope: Construct, id: string, props: DnsStackProps) {
    super(scope, id, props);

    this.zone = new HostedZone(this, 'Zone', {
      zoneName: props.domainName,
      comment: 'dawnbreak.app: the pages the App Store listing links',
    });

    // Printed rather than merely stored: these four are what gets typed into OVH's "use my own
    // DNS" form, and until they are, nothing else in this app can finish deploying.
    //
    // `Fn.join` rather than `Array.join`: the name servers are a CloudFormation token, so at synth
    // time this is one opaque string standing for a list, and joining it in TypeScript would
    // stringify the token instead of its contents.
    new CfnOutput(this, 'NameServers', {
      value: Fn.join(',', this.zone.hostedZoneNameServers ?? []),
      description: 'Set these as the domain\'s DNS servers at the registrar',
    });
    new CfnOutput(this, 'HostedZoneId', { value: this.zone.hostedZoneId });
  }
}
