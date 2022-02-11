import { useEffect, useState } from 'react'
import { useParams } from "react-router-dom";
import { VegaLite } from 'react-vega'
import { useOktaAuth } from '@okta/okta-react';
const API_BASE_URL = 'https://qpk1bm0kn4.execute-api.us-east-1.amazonaws.com/api'

export const Chart = () => {
  const [spec, setSpec] = useState<any | null>(null)
  const { id } = useParams() as any;
  const { authState } = useOktaAuth()

  useEffect(() => {
    const init = async () => {
      if (authState?.accessToken?.accessToken) {
        const response = await fetch(`${API_BASE_URL}/${id}.json`,
          {
            headers: {
              Authorization: 'Bearer ' + authState.accessToken.accessToken
            }
          }
        )

        const spec = await response.json()
        setSpec(spec)
      }
    }

    if (id) {
      init()
    }
  }, [id, authState])


  return (
    <div>
      {spec && <VegaLite spec={spec}/>}
    </div>
  )
}

