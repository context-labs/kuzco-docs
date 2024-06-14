import React from 'react';
import { Callout, Link } from "nextra-theme-docs";

export function WIP(){
  return (
    <Callout type="warning">
      This documentation is a work in progress. <Link href="https://discord.com/invite/kuzco" style={{textDecoration: 'underline'}}>Join Discord</Link> for more information.
    </Callout>
  )
}