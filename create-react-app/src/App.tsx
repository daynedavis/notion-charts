import { useState } from 'react';
import {
  Switch,
  Route,
  useHistory
} from "react-router-dom";
import './App.css';
import { Chart } from './Chart';
import { SecureRoute, Security, LoginCallback } from '@okta/okta-react';
import { OktaAuth, toRelativeUrl } from '@okta/okta-auth-js';
import { oktaAuthConfig } from './config';

const oktaAuth = new OktaAuth(oktaAuthConfig);

function App() {
  const [authRequired, setAuthRequired] = useState(false)

  const history = useHistory();
  const restoreOriginalUri = async (_oktaAuth: any, originalUri: any) => {
    history.push(toRelativeUrl(originalUri || '/', window.location.origin));
  };


  return (
      <Security
        oktaAuth={oktaAuth}
        restoreOriginalUri={restoreOriginalUri}
        onAuthRequired={() => setAuthRequired(true)}
      >
        <Switch>
          <Route path="/" exact component={LoginPage} />
          <SecureRoute path="/chart/:id" component={Chart}/>
          <Route path='/login/callback' component={LoginCallback} />
        </Switch>
        {authRequired && <LoginPage />}
      </Security>
  );
}

export default App;


const LoginPage = () => (
  <div className='h-full w-full flex justify-center items-center'>
    <button 
      className='pl-6 pr-6 pb-3 pt-3 h-12 rounded-md bg-blue-500 text-white'
      onClick={() => oktaAuth?.signInWithRedirect()}
    >
      Sign in with Okta
    </button>
  </div>
)