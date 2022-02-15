import express from 'express'
import OktaJwtVerifier from '@okta/jwt-verifier';
import S3 from 'aws-sdk/clients/s3'
import serverlessExpress from '@vendia/serverless-express'

const IS_LOCAL = false 
const BUCKET_NAME = 'notion-chart-data.com-sample'
const OKTA_DOMAIN = 'dev-83655047.okta.com'
const OKTA_AUDIENCE = 'api://default'

const oktaJwtVerifier = new OktaJwtVerifier({
  issuer: `https://${OKTA_DOMAIN}/oauth2/default`
});

const s3 = new S3()
const app = express()
const port = process.env.PORT || 8080;

app.get("*", async (req, res, next) => {
  try {
    const [bearer, token] = req.headers.authorization.split(' ')

    if (bearer !== 'Bearer') {
      console.log('reject')
      res.status(403).send('Invalid token')
    }

    try {
      await oktaJwtVerifier.verifyAccessToken(token, OKTA_AUDIENCE)
      const data = await s3.getObject({ Bucket: BUCKET_NAME, Key: req.path.replace('/', '') }).promise()

      res.set("Content-Length", data.ContentLength?.toString())
        .set("Content-Type",data.ContentType)

      res.send(data.Body)
    } catch (error) {
      res.status(403).send('User not authenticated')
    }
  } catch (err) {
      return res.status(500).send('Error fetching chart')
  }
})

export const handler = serverlessExpress({ app })

if (IS_LOCAL) {
  app.listen(port, () => console.log(`Listening on port ${port}`));
}