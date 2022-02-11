import type { NextPage } from 'next'
import Head from 'next/head'
import Image from 'next/image'
import { VegaLite } from 'react-vega'
import styles from '../styles/Home.module.css'
import chart1 from '../charts/chart1.json'

const Home: NextPage = () => {
  console.log('chart1', chart1)
  return (
    <div className={styles.container}>
      <VegaLite spec={chart1 as any}/>
    </div>
  )
}

export default Home
