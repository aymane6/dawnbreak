import { CfnOutput, Stack, StackProps } from 'aws-cdk-lib';
import { HostedZone } from 'aws-cdk-lib/aws-route53';
import { Construct } from 'constructs';
import { StaticSite } from '../constructs/StaticSite';

export interface SiteStackProps extends StackProps {
  readonly domainName: string;
  /** The zone `DnsStack` made. Looked up rather than exported so the two stacks stay independent. */
  readonly hostedZoneId: `Z${string}`;
  readonly contentPath: string;
}

/**
 * The site: certificate, bucket, distribution, records and the pages themselves.
 *
 * Deployed *after* the registrar points at the zone's name servers. The certificate is validated by
 * DNS, and ACM resolves that record over public DNS rather than by asking Route 53, so a deploy
 * attempted before the delegation is live will sit for hours and then fail.
 */
export class SiteStack extends Stack {
  constructor(scope: Construct, id: string, props: SiteStackProps) {
    super(scope, id, props);

    // Imported here rather than inside the construct: a construct that looks resources up cannot be
    // tested without an account, and cannot be reused against a zone somebody else owns.
    const zone = HostedZone.fromHostedZoneAttributes(this, 'Zone', {
      hostedZoneId: props.hostedZoneId,
      zoneName: props.domainName,
    });

    const site = new StaticSite(this, 'Site', {
      domainName: props.domainName,
      zone,
      contentPath: props.contentPath,
    });

    new CfnOutput(this, 'DistributionDomain', {
      value: site.distribution.distributionDomainName,
      description: 'The CloudFront host the alias records point at',
    });
    new CfnOutput(this, 'SiteUrl', { value: `https://${props.domainName}/` });
    new CfnOutput(this, 'PrivacyUrl', { value: `https://${props.domainName}/privacy` });
    new CfnOutput(this, 'TermsUrl', { value: `https://${props.domainName}/terms` });
  }
}
