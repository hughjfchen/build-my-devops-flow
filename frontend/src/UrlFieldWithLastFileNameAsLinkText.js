import * as React from 'react';
import { Link } from '@mui/material';
import { useRecordContext } from 'react-admin';
import LaunchIcon from '@mui/icons-material/Launch';

const UrlFieldWithLastFileNameAsLinkText = ( { source } ) => {
    const record = useRecordContext();

    return record ? (
        <Link
            href={record[source]}
          sx = {{ textDecoration: 'none' }}
            variant="body2"
        >
            {record[source].split('/').pop()}
        <LaunchIcon sx = {{ width: '0.5em', height: '0.5em', paddingLeft: 2 }} />
        </Link>
    ) : null;
};


export default UrlFieldWithLastFileNameAsLinkText;
