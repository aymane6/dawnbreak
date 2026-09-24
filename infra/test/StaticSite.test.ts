import { App, Stack } from 'aws-cdk-lib';
import { Match, Template } from 'aws-cdk-lib/assertions';
import { HostedZone } from 'aws-cdk-lib/aws-route53';
import { StaticSite } from '../src/constructs/StaticSite';

const ENVIRONMENT = { account: '123456789012', region: 'us-east-1' };

function subject(): Template {
  const stack = new Stack(new App(), 'Test', { env: ENVIRONMENT });
  const zone = HostedZone.fromHostedZoneAttributes(stack, 'Zone', {
    hostedZoneId: 'Z01978801VH16H8J00TJR',
    zoneName: 'dawnbreak.app',
  });
  new StaticSite(stack, 'Site', {
    domainName: 'dawnbreak.app',
    zone,
    contentPath: '../docs',
  });
  return Template.fromStack(stack);
}

test('the bucket is private, encrypted and versioned', () => {
  subject().hasResourceProperties('AWS::S3::Bucket', {
    PublicAccessBlockConfiguration: {
      BlockPublicAcls: true,
      BlockPublicPolicy: true,
      IgnorePublicAcls: true,
      RestrictPublicBuckets: true,
    },
    VersioningConfiguration: { Status: 'Enabled' },
    BucketEncryption: Match.objectLike({
      ServerSideEncryptionConfiguration: Match.anyValue(),
    }),
  });
});

test('only CloudFront can read the bucket', () => {
  // Origin access control rather than a public bucket or a signed URL: the pages are public, but a
  // public bucket answers on an s3 hostname that carries no certificate for this domain.
  subject().hasResourceProperties('AWS::S3::BucketPolicy', {
    PolicyDocument: Match.objectLike({
      Statement: Match.arrayWith([
        Match.objectLike({
          Principal: { Service: 'cloudfront.amazonaws.com' },
          Action: 's3:GetObject',
        }),
      ]),
    }),
  });
  subject().resourceCountIs('AWS::CloudFront::OriginAccessControl', 1);
});

test('the distribution answers for the apex and for www, over HTTPS only', () => {
  subject().hasResourceProperties('AWS::CloudFront::Distribution', {
    DistributionConfig: Match.objectLike({
      Aliases: Match.arrayWith(['dawnbreak.app', 'www.dawnbreak.app']),
      DefaultRootObject: 'index.html',
      HttpVersion: 'http2and3',
      PriceClass: 'PriceClass_100',
      DefaultCacheBehavior: Match.objectLike({ ViewerProtocolPolicy: 'redirect-to-https' }),
    }),
  });
});

test('the certificate covers both names and validates through the zone', () => {
  subject().hasResourceProperties('AWS::CertificateManager::Certificate', {
    DomainName: 'dawnbreak.app',
    SubjectAlternativeNames: ['www.dawnbreak.app'],
    ValidationMethod: 'DNS',
    DomainValidationOptions: Match.arrayWith([
      Match.objectLike({ DomainName: 'dawnbreak.app', HostedZoneId: 'Z01978801VH16H8J00TJR' }),
    ]),
  });
});

test('extensionless paths are rewritten, because the app links /privacy with no extension', () => {
  const template = subject();
  template.resourceCountIs('AWS::CloudFront::Function', 1);
  const functions = template.findResources('AWS::CloudFront::Function');
  const code = Object.values(functions)[0].Properties.FunctionCode as string;
  expect(code).toContain("uri + '.html'");
  expect(code).toContain("uri + 'index.html'");
  template.hasResourceProperties('AWS::CloudFront::Distribution', {
    DistributionConfig: Match.objectLike({
      DefaultCacheBehavior: Match.objectLike({
        FunctionAssociations: Match.arrayWith([
          Match.objectLike({ EventType: 'viewer-request' }),
        ]),
      }),
    }),
  });
});

test('HSTS is sent with preload, since .app is a preloaded TLD', () => {
  subject().hasResourceProperties('AWS::CloudFront::ResponseHeadersPolicy', {
    ResponseHeadersPolicyConfig: Match.objectLike({
      SecurityHeadersConfig: Match.objectLike({
        StrictTransportSecurity: {
          AccessControlMaxAgeSec: 63072000,
          IncludeSubdomains: true,
          Preload: true,
          Override: true,
        },
        ContentTypeOptions: { Override: true },
        FrameOptions: { FrameOption: 'DENY', Override: true },
      }),
    }),
  });
});

test('both names resolve over IPv4 and IPv6', () => {
  const template = subject();
  template.resourceCountIs('AWS::Route53::RecordSet', 4);
  for (const [name, type] of [
    ['dawnbreak.app.', 'A'],
    ['dawnbreak.app.', 'AAAA'],
    ['www.dawnbreak.app.', 'A'],
    ['www.dawnbreak.app.', 'AAAA'],
  ]) {
    template.hasResourceProperties('AWS::Route53::RecordSet', {
      Name: name,
      Type: type,
      AliasTarget: Match.objectLike({ DNSName: Match.anyValue() }),
    });
  }
});

test('the pages are deployed and the edge invalidated', () => {
  const template = subject();
  template.resourceCountIs('Custom::CDKBucketDeployment', 1);
  template.hasResourceProperties('Custom::CDKBucketDeployment', {
    DistributionPaths: ['/*'],
    Prune: true,
  });
});
